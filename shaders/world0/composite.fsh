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
#include "/lib/frag/dither.glsl"
#include "/lib/frag/noise.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/util/utils.glsl"
#include "/lib/lighting/raytracer.glsl"
#include "/lib/util/distort.glsl"
#include "/lib/lighting/shadows.glsl"

void main() {

   vec3 Shadow = vec3(1.0);
   #if SHADOWS == 1
      Shadow = shadowMap(getViewPos(), shadowMapResolution);
   #endif

   /*DRAWBUFFERS:7*/
   gl_FragData[0] = vec4(Shadow, 1.0);
}