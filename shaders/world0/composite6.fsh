#version 400 compatibility
#include "/programs/extensions.glsl"

/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

varying vec2 texCoords;

#include "/settings.glsl"
#include "/programs/common.glsl"
#include "/lib/util/blur.glsl"
#include "/lib/fragment/brdf.glsl"
#include "/lib/fragment/raytracer.glsl"
#include "/lib/fragment/ssr.glsl"
#include "/lib/fragment/svgf.glsl"

void main() {
    vec4 Result = texture(colortex0, texCoords);
    bool sky = isSky(texCoords);

    vec3 viewPos = getViewPos(texCoords);
    vec3 normal = normalize(decodeNormal(texture(colortex1, texCoords).xy));

    if(!sky) {
        #if GI == 1
            vec3 globalIllumination = vec3(0.0);
            #if GI_FILTER == 1
                globalIllumination = SVGF(colortex9, viewPos, normal, texCoords, vec2(0.0, 1.0));
            #else
                globalIllumination = texture(colortex9, texCoords).rgb;
            #endif
            Result.rgb = max(vec3(0.0), globalIllumination);
        #endif
    }

    #if SSR == 1
        if(!sky) {
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
            Result.rgb = mix(Result.rgb, clamp01(reflections), DFG);
        }
    #endif

    #if VL == 1
        vec3 volumetricLighting = vec3(0.0);
        #if VL_FILTER == 1
            volumetricLighting = boxBlur(texCoords, colortex8, 5).rgb;
        #else
            volumetricLighting = texture(colortex8, texCoords).rgb;
        #endif
        
        Result.rgb += (viewPosSkyColor(viewPos) * volumetricLighting);
    #endif

    vec3 brightSpots;
    #if BLOOM == 1
        brightSpots = luma(Result.rgb) > BLOOM_LUMA_THRESHOLD ? Result.rgb : vec3(0.0);
    #endif

    /*DRAWBUFFERS:05*/
    gl_FragData[0] = Result;
    gl_FragData[1] = vec4(brightSpots, 1.0);
}
