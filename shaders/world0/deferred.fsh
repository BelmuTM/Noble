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
#include "/lib/util/worldTime.glsl"

/*
const int colortex0Format = RGBA16F;
const int colortex4Format = RGBA16F;
*/

void main() {

     if(texture2D(depthtex0, texCoords).r == 1.0) {
          vec3 sunDir = normalize(shadowLightPosition);
          vec3 viewPos = getViewPos(texCoords);
          vec3 eyeDir = normalize(mat3(gbufferModelViewInverse) * viewPos);

          float angle = smoothstep(0.9991, 0.99995, dot(sunDir, normalize(viewPos)));
          vec3 sky = mix(getDayTimeSkyGradient(eyeDir, viewPos), vec3(1.0) + (1.0 - angle), angle); 
          
          /*DRAWBUFFERS:0*/
          gl_FragData[0] = vec4(sky, 1.0);
          return;
     }

     /*DRAWBUFFERS:4*/
     gl_FragData[0] = texture2D(colortex0, texCoords);
}