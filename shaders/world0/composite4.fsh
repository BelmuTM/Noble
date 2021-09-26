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
#include "/lib/material.glsl"
#include "/lib/fragment/brdf.glsl"
#include "/lib/fragment/raytracer.glsl"
#include "/lib/fragment/ssr.glsl"

void main() {
     vec4 Result = texture(colortex0, texCoords);
     vec3 roughReflections = vec3(0.0);

     #if SSR == 1
          #if SSR_TYPE == 1
               float inverseRes = 1.0 / ROUGH_REFLECT_RES;
               vec2 scaledUv = texCoords * inverseRes;
        
               if(clamp(texCoords, vec2(0.0), vec2(ROUGH_REFLECT_RES)) == texCoords && !isSky(scaledUv)) {
                    vec3 normalAt = normalize(decodeNormal(texture(colortex1, scaledUv).xy));
                    float roughness = texture(colortex2, scaledUv).r;

                    float F0 = texture(colortex2, scaledUv).g;
                    bool isMetal = F0 * 255.0 > 229.5;
                    vec3 specularColor = mix(vec3(F0), texture(colortex4, scaledUv).rgb, float(isMetal));
                    roughReflections = prefilteredReflections(scaledUv, getViewPos(scaledUv), normalAt, roughness * roughness, specularColor, isMetal);
               }
          #endif
     #endif

     if(!isSky(texCoords)) {
          bool isMetal = texture(colortex2, texCoords).g * 255.0 > 229.5;

          if(!isMetal) {
               vec3 viewPos = getViewPos(texCoords);
               vec3 normal = normalize(decodeNormal(texture(colortex1, texCoords).xy));

               vec3 globalIllumination = vec3(0.0);
               #if GI == 1
                    #if GI_FILTER == 1
                         globalIllumination = heavyGaussianFilter(texCoords, viewPos, normal, colortex6, vec2(0.0, 1.0)).rgb;
                    #else
                         globalIllumination = texture(colortex6, texCoords).rgb;
                    #endif
                    globalIllumination = saturate(globalIllumination);

                    #if GI_VISUALIZATION == 0
                         Result.rgb += globalIllumination * texture(colortex4, texCoords).rgb;
                    #else
                         Result.rgb = globalIllumination;
                    #endif
               #else
                    #if AO == 1
                         #if AO_FILTER == 1
                              Result.rgb *= heavyGaussianFilter(texCoords, viewPos, normal, colortex5, vec2(0.0, 1.0)).a;
                         #else
                              Result.rgb *= saturate(texture(colortex5, texCoords).a);
                         #endif
                    #endif
               #endif
          }
     }

     /*DRAWBUFFERS:05*/
     gl_FragData[0] = Result;
     gl_FragData[1] = vec4(roughReflections, 1.0);
}