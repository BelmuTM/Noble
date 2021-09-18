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
#include "/lib/uniforms.glsl"
#include "/lib/fragment/bayer.glsl"
#include "/lib/fragment/noise.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/util/utils.glsl"
#include "/lib/util/worldTime.glsl"
#include "/lib/util/blur.glsl"
#include "/lib/material.glsl"
#include "/lib/lighting/brdf.glsl"
#include "/lib/lighting/raytracer.glsl"
#include "/lib/lighting/ssr.glsl"

void main() {
     vec4 Result = texture2D(colortex0, texCoords);
     vec3 roughReflections = vec3(0.0);

     #if SSR == 1
          #if SSR_TYPE == 1
               float inverseRes = 1.0 / ROUGH_REFLECT_RES;
               vec2 scaledUv = texCoords * inverseRes;
        
               if(clamp(texCoords, vec2(0.0), vec2(ROUGH_REFLECT_RES)) == texCoords && !isSky(scaledUv)) {
                    vec3 normalAt = normalize(decodeNormal(texture2D(colortex1, scaledUv).xy));
                    bool isMetal = texture2D(colortex2, scaledUv).g * 255.0 > 229.5;
                    float roughness = texture2D(colortex2, scaledUv).r;

                    roughReflections = prefilteredReflections(scaledUv, getViewPos(scaledUv), normalAt, roughness * roughness, isMetal);
               }
          #endif
     #endif

     if(!isSky(texCoords)) {
          float F0 = texture2D(colortex2, texCoords).g;
          bool isMetal = F0 * 255.0 > 229.5;

          vec3 globalIllumination = vec3(0.0);

          if(!isMetal) {
               #if GI == 1
                    #if GI_FILTER == 1
                         vec3 viewPos = getViewPos(texCoords);
                         vec3 normal = normalize(decodeNormal(texture2D(colortex1, texCoords).xy));

                         globalIllumination = gaussianFilter(texCoords, viewPos, normal, colortex6, vec2(0.0, 1.0)).rgb;
                    #else
                         globalIllumination = texture2D(colortex6, texCoords).rgb;
                    #endif

                    #if GI_VISUALIZATION == 0
                         Result.rgb += globalIllumination * texture2D(colortex4, texCoords).rgb;
                    #else
                         Result.rgb = globalIllumination;
                    #endif
               #else
                    #if AO == 1
                         #if AO_FILTER == 1
                              Result.rgb *= gaussianBlur(texCoords, colortex6, vec2(0.0, 1.0)).a;
                         #else
                              Result.rgb *= texture2D(colortex6, texCoords).a;
                         #endif
                    #endif
               #endif
          }
     }

     /*DRAWBUFFERS:05*/
     gl_FragData[0] = Result;
     gl_FragData[1] = vec4(roughReflections, 1.0);
}