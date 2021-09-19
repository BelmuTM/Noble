/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#version 330 compatibility

#include "/settings.glsl"
#include "/lib/util/distort.glsl"

varying vec2 texCoords;
varying vec4 color;

void main(){
    gl_Position = ftransform();
    gl_Position.xy = distort3(gl_Position.xy);
    texCoords = gl_MultiTexCoord0.st;
    color = gl_Color;
}
