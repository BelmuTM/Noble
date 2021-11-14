#version 400 compatibility
#include "/include/extensions.glsl"

/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

varying vec2 texCoords;
varying vec4 color;

#include "/include/uniforms.glsl"

void main() {
    /*DRAWBUFFERS:5*/
    gl_FragData[0] = texture(colortex0, texCoords) * color;
}
