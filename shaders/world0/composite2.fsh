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

/*
    Temporal Anti-Aliasing from "Temporal Reprojection Anti-Aliasing in INSIDE"
    http://s3.amazonaws.com/arena-attachments/655504/c5c71c5507f0f8bf344252958254fb7d.pdf?1468341463
*/

vec4 clipAABB(vec4 minColor, vec4 maxColor, vec4 prevColor) {
    vec4 pClip = 0.5 * (maxColor + minColor); // Center
    vec4 eClip = 0.5 * (maxColor - minColor); // Size

    vec4 vClip = prevColor * pClip;
    vec3 vUnit = vClip.xyz / eClip.xyz;
    vec3 aUnit = abs(vUnit);
    float denom = max(aUnit.x, max(aUnit.y, aUnit.z));

    return denom > 1.0 ? pClip + vClip / denom : prevColor;
}

vec4 neighborhoodClamping(sampler2D currColorTex, vec4 currColor, vec4 prevColor) {
    vec4 minColor = prevColor, maxColor = prevColor;

    for(int x = -2; x <= 2; x++) {
        for(int y = -2; y <= 2; y++) {
            vec4 color = texture2D(currColorTex, texCoords + (vec2(x, y) * pixelSize)); 
            minColor = min(minColor, color); maxColor = max(maxColor, color); 
        }
    }
    return clipAABB(minColor, maxColor, prevColor);
}

void main() {
    vec4 GlobalIllumination = texture2D(colortex5, texCoords);
    vec4 GlobalIlluminationResult = GlobalIllumination;
    
    #if GI == 1
        #if GI_TEMPORAL_ACCUMULATION == 1
            // Thanks Stubman#8195 and swr#1899 for the help!
            vec2 prevTexCoords = reprojection(vec3(texCoords, texture2D(depthtex1, texCoords).r));
            vec4 prevColor = texture2D(colortex6, prevTexCoords);

            prevColor = neighborhoodClamping(colortex5, GlobalIllumination, prevColor);
            vec2 velocity = (texCoords - prevTexCoords) * viewSize;

            float blendFactor = float(!any(greaterThan(prevTexCoords, vec2(1.0))));
            blendFactor *= exp(-length(velocity)) * 0.6 + 0.3;

            GlobalIlluminationResult = mix(GlobalIlluminationResult, prevColor, blendFactor); 
        #endif
    #endif

    /*DRAWBUFFERS:6*/
    gl_FragData[0] = GlobalIlluminationResult;
}
