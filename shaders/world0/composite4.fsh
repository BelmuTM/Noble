/***********************************************/
/*       Copyright (C) Noble RT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#version 400 compatibility

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

     vec3 roughReflections;
     #if SSR == 1
        #if SSR_TYPE == 1
               float inverseRes = 1.0 / ROUGH_REFLECT_RES;
               vec2 scaledUv = texCoords * inverseRes;
        
               if(clamp(texCoords, vec2(0.0), vec2(ROUGH_REFLECT_RES)) == texCoords) {
                    vec3 positionAt = vec3(scaledUv, texture2D(depthtex0, scaledUv).r);
                    vec3 normalAt = normalize(decodeNormal(texture2D(colortex1, scaledUv).xy));
        
                    float roughness = texture2D(colortex2, scaledUv).r;
                    roughReflections = prefilteredReflections(screenToView(positionAt), normalAt, roughness * roughness);
               }
          #endif
     #endif

     #if GI == 1
          vec3 globalIllumination = clamp(texture2D(colortex6, texCoords).rgb, 0.0, 1.0);

          #if GI_FILTER == 1
               vec3 viewPos = getViewPos();
               vec3 normal = normalize(decodeNormal(texture2D(colortex1, texCoords).xy));

               globalIllumination = spatialDenoiser(1.0, viewPos, normal, colortex6, 
                   viewSize * GI_FILTER_RES, GI_FILTER_SIZE, GI_FILTER_QUALITY, 10.0).rgb;
          #endif

          Result.rgb += globalIllumination * texture2D(colortex4, texCoords).rgb;
     #else
          Result.rgb *= texture2D(colortex6, texCoords).a; // Ambient Occlusion
     #endif

     /*DRAWBUFFERS:05*/
     gl_FragData[0] = Result;
     gl_FragData[1] = vec4(roughReflections, 1.0);
}