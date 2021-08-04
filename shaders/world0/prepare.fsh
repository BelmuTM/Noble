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

void main() {
     /*DRAWBUFFERS:4*/
     gl_FragData[0] = vec4(1.0, 0.0, 0.0, 1.0);
}
