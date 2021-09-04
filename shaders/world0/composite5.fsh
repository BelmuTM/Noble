/***********************************************/
/*       Copyright (C) Noble RT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#version 330 compatibility

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
    vec4 Result = texture2D(colortex0, texCoords);

    #if SSR == 1
        if(!isSky()) {
            vec3 viewPos = getViewPos(texCoords);
            vec3 normal = normalize(decodeNormal(texture2D(colortex1, texCoords).xy));

            float NdotV = saturate(dot(normal, normalize(-viewPos)));
            float F0 = texture2D(colortex2, texCoords).g;
            bool isMetal = F0 * 255.0 > 229.5;

            vec3 specularColor = mix(vec3(F0), texture2D(colortex4, texCoords).rgb, float(isMetal));
            float roughness = texture2D(colortex2, texCoords).r;

            vec3 reflections;
            #if SSR_TYPE == 1
                reflections = texture2D(colortex5, texCoords * ROUGH_REFLECT_RES).rgb;
            #else
                reflections = simpleReflections(viewPos, normal, NdotV, specularColor, isMetal);
            #endif

            vec3 DFG = envBRDFApprox(specularColor, roughness, NdotV);
            Result.rgb = mix(Result.rgb, reflections, DFG);
        }
    #endif

    float volumetricLighting = texture2D(colortex4, texCoords).a;
    #if VL == 1
        #if VL_FILTER == 1
            volumetricLighting = bilateralBlur(texCoords, colortex4, 5).a;
        #endif

        Result.rgb = mix(Result.rgb, getSunColor() * 0.07 * volumetricLighting, 0.62);
    #endif

    vec3 brightSpots;
    #if BLOOM == 1
        brightSpots = luma(Result.rgb) > BLOOM_LUMA_THRESHOLD ? Result.rgb : vec3(0.0);
    #endif

    /*DRAWBUFFERS:05*/
    gl_FragData[0] = Result;
    gl_FragData[1] = vec4(brightSpots, 1.0);
}
