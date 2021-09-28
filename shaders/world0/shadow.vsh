#version 400 compatibility
#include "/programs/extensions.glsl"

/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util/math.glsl"

varying vec2 texCoords;
varying vec4 color;

void main(){
    gl_Position = ftransform();
    gl_Position.xy = distort(gl_Position.xy);
    texCoords = gl_MultiTexCoord0.st;
    color = gl_Color;
}
