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
#include "/lib/fragment/noise.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/util/utils.glsl"
#include "/lib/util/worldTime.glsl"
#include "/lib/material.glsl"
#include "/lib/lighting/brdf.glsl"
#include "/lib/lighting/raytracer.glsl"
#include "/lib/lighting/ssr.glsl"

void main() {
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

     /*DRAWBUFFERS:5*/
     gl_FragData[0] = vec4(roughReflections, 1.0);
}