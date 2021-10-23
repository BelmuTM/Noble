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
     vec3 reflections = vec3(0.0), specularColor = vec3(0.0);

     #if SSR == 1
          float resolution = SSR_TYPE == 1 ? ROUGH_REFLECT_RES : 1.0;
          vec2 scaledUv = texCoords * (1.0 / resolution);
        
          if(clamp(texCoords, vec2(0.0), vec2(resolution)) == texCoords && !isSky(scaledUv)) {
               vec3 normalAt = normalize(decodeNormal(texture(colortex1, scaledUv).xy));
               vec3 posAt = getViewPos(scaledUv);

               float roughness = texture(colortex2, scaledUv).r;
               float F0 = texture(colortex2, scaledUv).g;
               bool isMetal = F0 * 255.0 > 229.5;
               specularColor = getSpecularColor(F0, texture(colortex4, scaledUv).rgb);
                    
               #if SSR_TYPE == 1
                    reflections = prefilteredReflections(scaledUv, posAt, normalAt, roughness * roughness, specularColor, isMetal);
               #else
                    float NdotV = max(EPS, dot(normalAt, -normalize(posAt)));
                    reflections = simpleReflections(scaledUv, posAt, normalAt, NdotV, specularColor, isMetal);
               #endif
          }
     #endif

     vec3 globalIllumination = vec3(0.0);
     if(!isSky(texCoords)) {
          #if GI == 1
               #if GI_FILTER == 1
                    vec3 viewPos = getViewPos(texCoords);
                    vec3 normal = normalize(decodeNormal(texture(colortex1, texCoords).xy));

                    globalIllumination = SVGF(colortex5, viewPos, normal, texCoords, vec2(0.0, 1.0));
               #else
                    globalIllumination = texture(colortex5, texCoords).rgb;
               #endif
          #else
               #if AO == 1
                    #if AO_FILTER == 1
                         bool isMetal = texture(colortex2, texCoords).g * 255.0 > 229.5;
                         Result.rgb *= isMetal ? 1.0 : gaussianBlur(texCoords, colortex5, vec2(0.0, 1.0), 1.0).a;
                    #endif
               #endif
          #endif
     }

     /*DRAWBUFFERS:0459*/
     gl_FragData[0] = Result;
     gl_FragData[1] = vec4(specularColor, 1.0);
     gl_FragData[2] = vec4(reflections, 1.0);
     gl_FragData[3] = vec4(globalIllumination, 1.0);
}
