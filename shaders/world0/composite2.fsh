/***********************************************/
/*       Copyright (C) Noble RT - 2021       */
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
#include "/lib/uniforms.glsl"
#include "/lib/frag/dither.glsl"
#include "/lib/frag/noise.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/util/utils.glsl"
#include "/lib/util/reprojection.glsl"

/*
const int colortex6Format = RGBA16F;
*/

const bool colortex6Clear = false;

/*
    Temporal Anti-Aliasing from "Temporal Reprojection Anti-Aliasing in INSIDE"
    http://s3.amazonaws.com/arena-attachments/655504/c5c71c5507f0f8bf344252958254fb7d.pdf?1468341463
*/

vec3 clipAABB(vec3 prevColor, vec3 minColor, vec3 maxColor) {
    vec3 pClip = 0.5 * (maxColor + minColor); // Center
    vec3 eClip = 0.5 * (maxColor - minColor); // Size

    vec3 vClip = prevColor - pClip;
    vec3 vUnit = vClip / eClip;
    vec3 aUnit = abs(vUnit);
    float denom = max(aUnit.x, max(aUnit.y, aUnit.z));

    return denom > 1.0 ? pClip + vClip / denom : prevColor;
}

vec3 neighborhoodClamping(sampler2D currColorTex, vec3 currColor, vec3 prevColor) {
    vec3 minColor = prevColor, maxColor = prevColor;

    for(int x = -2; x <= 2; x++) {
        for(int y = -2; y <= 2; y++) {
            vec3 color = texture2D(currColorTex, texCoords + vec2(x, y) * pixelSize).rgb; 
            minColor = min(minColor, color); maxColor = max(maxColor, color); 
        }
    }
    return clipAABB(prevColor, minColor, maxColor);
}

void main() {
    /* Upscaling Global Illumination */
    vec3 GlobalIllumination = texture2D(colortex5, texCoords * GI_RESOLUTION).rgb;
    vec3 GlobalIlluminationResult = GlobalIllumination;
    
    #if GI == 1
        #if GI_TEMPORAL_ACCUMULATION == 1
            // Thanks Stubman#8195 and swr#1899 for the help!
            vec2 prevTexCoords = reprojection(vec3(texCoords, texture2D(depthtex0, texCoords).r));
            vec3 prevColor = texture2D(colortex6, prevTexCoords).rgb;
            prevColor = neighborhoodClamping(colortex6, GlobalIllumination, prevColor);

            vec2 velocity = (texCoords - prevTexCoords) * viewSize;
            float blendFactor = float(clamp(prevTexCoords, vec2(0.0), vec2(1.0)) == prevTexCoords);
            blendFactor *= exp(-length(velocity)) * 0.6 + 0.3;

            GlobalIlluminationResult = mix(GlobalIlluminationResult, prevColor, blendFactor); 
        #endif
    #endif

    /*DRAWBUFFERS:6*/
    gl_FragData[0] = vec4(GlobalIlluminationResult, 1.0);
}
