/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#version 330

varying vec2 texCoords;

#include "/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/fragment/bayer.glsl"
#include "/lib/fragment/noise.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/util/utils.glsl"
#include "/lib/util/color.glsl"
#include "/lib/util/worldTime.glsl"
#include "/lib/util/blur.glsl"
#include "/lib/material.glsl"
#include "/lib/lighting/brdf.glsl"
#include "/lib/lighting/raytracer.glsl"
#include "/lib/lighting/ssr.glsl"

void main() {
    vec4 Result = texture(colortex0, texCoords);
    bool sky = isSky(texCoords);

    #if SSR == 1
        if(!sky) {
            vec3 viewPos = getViewPos(texCoords);
            vec3 normal = normalize(decodeNormal(texture(colortex1, texCoords).xy));

            float NdotV = abs(dot(normal, normalize(-viewPos))) + 1e-5;
            float F0 = texture(colortex2, texCoords).g;
            bool isMetal = F0 * 255.0 > 229.5;

            vec3 specularColor = mix(vec3(F0), texture(colortex4, texCoords).rgb, float(isMetal));
            float roughness = texture(colortex2, texCoords).r;

            vec3 reflections;
            #if SSR_TYPE == 1
                reflections = texture(colortex5, texCoords * ROUGH_REFLECT_RES).rgb;
            #else
                reflections = simpleReflections(texCoords, viewPos, normal, NdotV, specularColor, isMetal);
            #endif

            vec3 DFG = envBRDFApprox(specularColor, roughness, NdotV);
            Result.rgb = mix(Result.rgb, reflections, DFG);
        }
    #endif

    vec3 volumetricLighting = texture(colortex8, texCoords).rgb;
    #if VL == 1
        #if VL_FILTER == 1
            volumetricLighting = boxBlur(texCoords, colortex8, 5).rgb;
        #endif
        Result.rgb += (getDayColor() * volumetricLighting) * VL_BRIGHTNESS;
    #endif

    vec3 brightSpots;
    #if BLOOM == 1
        if(!sky) {
            bool isEmissive = texture(colortex1, texCoords).z > 0.2;
            brightSpots = isEmissive || luma(Result.rgb) > BLOOM_LUMA_THRESHOLD ? Result.rgb : vec3(0.0);
        }
    #endif

    /*DRAWBUFFERS:05*/
    gl_FragData[0] = Result;
    gl_FragData[1] = vec4(brightSpots, 1.0);
}
