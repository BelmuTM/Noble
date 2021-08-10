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

void main() {

     if(texture2D(depthtex0, texCoords).r == 1.0) {
          vec3 sunDir = normalize(shadowLightPosition);
          vec3 viewDir = normalize(getViewPos());

          vec3 sky = mix(vec3(1.0), getDayTimeSkyGradient(texCoords.y), step(dot(sunDir, viewDir), 0.999));
          
          /*DRAWBUFFERS:0*/
          gl_FragData[0] = vec4(sky, 1.0);
          return;
     }

     /*DRAWBUFFERS:4*/
     gl_FragData[0] = texture2D(colortex0, texCoords);
}