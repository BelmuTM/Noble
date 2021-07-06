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
#include "/lib/util/reprojection.glsl"

vec4 NeighborClamping(sampler2D currColorTex, vec4 currColor, vec4 prevColor, vec2 resolution) {
    vec4 minColor = currColor, maxColor = currColor;

    for(int x = -2; x <= 2; x++) {
        for(int y = -2; y <= 2; y++) {
            vec4 color = texture2D(currColorTex, texCoords + (vec2(x, y) * resolution)); 
            minColor = min(minColor, color);
            maxColor = max(maxColor, color); 
        }
    }
    minColor -= 0.075; 
    maxColor += 0.075; 
    return clamp(prevColor, minColor, maxColor); 
}

void main() {
    vec4 GlobalIllumination = texture2D(colortex6, texCoords);
    vec4 GlobalIlluminationResult = GlobalIllumination;
    
    #if PTGI == 1
        #if PTGI_TEMPORAL_ACCUMULATION == 1
            // Thanks Stubman#8195 and swr#1899 for the help!
            vec2 resolution = vec2(viewWidth, viewHeight);
            vec2 prevTexCoords = reprojection(vec3(texCoords, texture2D(depthtex1, texCoords).r));
            vec4 prevColor = texture2D(colortex7, prevTexCoords);

            prevColor = NeighborClamping(colortex6, GlobalIllumination, prevColor, 1.0 / resolution);
            vec2 velocity = (texCoords - prevTexCoords) * resolution;

            float blendFactor = float(
                prevTexCoords.x > 0.0 && prevTexCoords.x < 1.0 &&
                prevTexCoords.y > 0.0 && prevTexCoords.y < 1.0
            );
            blendFactor *= exp(-length(velocity)) * 0.6 + 0.3;
            GlobalIlluminationResult = mix(GlobalIlluminationResult, prevColor, blendFactor); 
        #endif
    #endif

    /*DRAWBUFFERS:7*/
    gl_FragData[0] = GlobalIlluminationResult;
}
