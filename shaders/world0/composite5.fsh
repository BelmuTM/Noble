/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#version 330 compatibility

varying vec2 texCoords;

#include "/settings.glsl"
#include "/common.glsl"
#include "/lib/util/blur.glsl"
#include "/lib/fragment/brdf.glsl"
#include "/lib/fragment/raytracer.glsl"
#include "/lib/fragment/ssr.glsl"

void main() {
    vec4 Result = texture(colortex0, texCoords);
    bool sky = isSky(texCoords);

    #if SSR == 1
        if(!sky) {
            vec3 viewPos = getViewPos(texCoords);
            vec3 normal = normalize(decodeNormal(texture(colortex1, texCoords).xy));

            float NdotV = max(EPS, dot(normal, -normalize(viewPos)));
            float F0 = texture(colortex2, texCoords).g;
            bool isMetal = F0 * 255.0 > 229.5;

            vec3 specularColor = getSpecularColor(F0, texture(colortex4, texCoords).rgb);
            float roughness = texture(colortex2, texCoords).r;

            vec3 reflections;
            #if SSR_TYPE == 1
                reflections = texture(colortex5, texCoords * ROUGH_REFLECT_RES).rgb;
            #else
                reflections = simpleReflections(texCoords, viewPos, normal, NdotV, specularColor, isMetal);
            #endif

            vec3 DFG = envBRDFApprox(specularColor, roughness, NdotV);
            Result.rgb = saturate(mix(Result.rgb, reflections, DFG));
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
        brightSpots = luma(Result.rgb) > BLOOM_LUMA_THRESHOLD ? Result.rgb : vec3(0.0);
    #endif

    /*DRAWBUFFERS:05*/
    gl_FragData[0] = Result;
    gl_FragData[1] = vec4(brightSpots, 1.0);
}
