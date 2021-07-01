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
#include "/lib/frag/noise.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/util/utils.glsl"
#include "/lib/util/gaussian.glsl"
#include "/lib/util/reprojection.glsl"

const bool colortex7Clear = false;

vec4 getNeighborClampedColor(sampler2D currColorTex, vec4 prevColor) {
    vec4 minColor = vec4(10000.0); 
    vec4 maxColor = vec4(-10000.0); 

    for(int x = -2; x <= 2; x++) {
        for(int y = -2; y <= 2; y++) {
            vec4 currColor = texture2D(currColorTex, texCoords + vec2(x, y)); 

            minColor = min(minColor, currColor); 
            maxColor = max(maxColor, currColor); 
        }
    }
    minColor -= 0.075; 
    maxColor += 0.075; 
    
    return clamp(prevColor, minColor, maxColor); 
}

void main() {
    vec4 Result = texture2D(colortex0, texCoords);
    
    float Depth = texture2D(depthtex0, texCoords).r;
    if(Depth == 1.0) {
        gl_FragData[0] = Result;
        return;
    }
    vec3 viewPos = getViewPos();
    vec3 Normal = normalize(texture2D(colortex1, texCoords).rgb * 2.0 - 1.0);

    float AmbientOcclusion = 0.0;
    // Blurring Ambient Occlusion
    int SAMPLES;
    for(int i = -4 ; i <= 4; i++) {
        for(int j = -3; j <= 3; j++) {
            vec2 offset = vec2((j * 1.0 / viewWidth), (i * 1.0 / viewHeight));
            AmbientOcclusion += texture2D(colortex5, texCoords + offset).a;
            SAMPLES++;
        }
    }
    AmbientOcclusion /= SAMPLES;

    vec4 GlobalIllumination = texture2D(colortex6, texCoords);
    vec4 GlobalIlluminationResult = GlobalIllumination;
    
    // Thanks Stubman#8195 and swr#1899 for the help!
    vec2 reprojectedTexCoords = reprojection(vec3(texCoords, texture2D(depthtex0, texCoords).r));
    vec4 reprojectedGlobalIllumination = getNeighborClampedColor(colortex6, texture2D(colortex7, reprojectedTexCoords));
    vec2 velocity = (texCoords - reprojectedTexCoords) * vec2(viewWidth, viewHeight); // Get velocity between frames

    float blendFactor = float(
        !any(greaterThan(reprojectedTexCoords.xy, vec2(1.0)))
    ); // If the reprojected texture coordinates are inside the screen
        
    blendFactor *= exp(-length(velocity)) * 0.35; // Make the blend factor depend on the velocity
    blendFactor = clamp(blendFactor + 0.85, 0.01, 0.9790); // The mix factor influences the amount of reprojected frames. 0.979 is around 23 frames

    GlobalIlluminationResult = mix(GlobalIllumination, reprojectedGlobalIllumination, blendFactor); // Mix GI with reprojected GI depending on the blend factor

    /* DRAWBUFFERS:07 */
    gl_FragData[0] = Result * AmbientOcclusion;
    gl_FragData[1] = GlobalIlluminationResult;
}
