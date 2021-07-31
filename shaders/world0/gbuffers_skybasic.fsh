/***********************************************/
/*       Copyright (C) Noble RT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#version 400 compatibility

varying vec2 texCoords;
varying vec4 color;

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;

#include "/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/frag/dither.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/transforms.glsl"

float drawCircle(vec2 coords, float radius) {
    return step(length(coords), radius);
}

void main() {
  	gl_FragData[0] = vec4(skyColor, 1.0);
}
