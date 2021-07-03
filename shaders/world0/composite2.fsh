/***********************************************/
/*       Copyright (C) Noble SSRT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#version 400 compatibility

varying vec2 texCoords;

uniform vec3 previousCameraPosition;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;

#include "/settings.glsl"
#include "/lib/composite_uniforms.glsl"
#include "/lib/frag/dither.glsl"
#include "/lib/frag/noise.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/util/utils.glsl"
#include "/lib/util/blur.glsl"
#include "/lib/util/reprojection.glsl"

const bool colortex7Clear = false;

vec2 neighborClampingOffsets[8] = vec2[8](
	vec2( 1.0, 0.0),
	vec2( 0.0, 1.0),
	vec2(-1.0, 0.0),
    vec2(0.0, -1.0),
    vec2(1.0, -1.0),
	vec2(-1.0, 1.0),
    vec2( 1.0, 1.0),
	vec2(-1.0, -1.0)
);

vec4 NeighborClamping(sampler2D currColorTex, vec4 currColor, vec4 prevColor, vec2 resolution) {
    vec4 minColor = currColor, maxColor = currColor;

    for(int i = 0; i < 8; i++) {
        vec4 color = texture2D(currColorTex, texCoords + (neighborClampingOffsets[i] * resolution)); 
        minColor = min(minColor, color);
        maxColor = max(maxColor, color); 
    }
    minColor -= 0.055; 
    maxColor += 0.055; 
    return clamp(prevColor, minColor, maxColor); 
}

void main() {
    vec4 Result = texture2D(colortex0, texCoords);
    
    float Depth = texture2D(depthtex0, texCoords).r;
    if(Depth == 1.0) {
        gl_FragData[0] = Result;
        return;
    }

    #if SSAO == 1
        float AmbientOcclusion = bilateralBlur(colortex5).a;
        Result *= AmbientOcclusion;
    #endif

    vec4 GlobalIllumination = texture2D(colortex6, texCoords);
    vec4 GlobalIlluminationResult = GlobalIllumination;
    
    #if SSGI == 1
        #if SSGI_TEMPORAL_ACCUMULATION == 1
            // Thanks Stubman#8195 and swr#1899 for the help!
            vec2 resolution = vec2(viewWidth, viewHeight);
            vec2 reprojectedTexCoords = reprojection(vec3(texCoords, texture2D(depthtex0, texCoords).r));
            vec4 reprojectedGlobalIllumination = texture2D(colortex7, reprojectedTexCoords);

            reprojectedGlobalIllumination = NeighborClamping(colortex6, GlobalIllumination, reprojectedGlobalIllumination, 1.0 / resolution);
            vec2 velocity = (texCoords - reprojectedTexCoords) * resolution; // Get velocity between frames

            float blendFactor = float(
                !any(greaterThan(reprojectedTexCoords.xy, vec2(1.0)))
            );  // If the reprojected texture coordinates are inside the screen
        
            blendFactor *= exp(-length(velocity)) * 0.4 + 0.3; // Make the blend factor depend on the velocity
            blendFactor = clamp(blendFactor + 0.7, 0.01, 0.825); // The mix factor influences the amount of reprojected frames. 0.979 is around 23 frames

            GlobalIlluminationResult = mix(GlobalIllumination, reprojectedGlobalIllumination, blendFactor); // Mix GI with reprojected GI depending on the blend factor
        #endif
    #endif

    /* DRAWBUFFERS:07 */
    gl_FragData[0] = Result;
    gl_FragData[1] = GlobalIlluminationResult;
}
