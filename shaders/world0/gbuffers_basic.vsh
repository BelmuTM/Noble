/***********************************************/
/*       Copyright (C) Noble SSRT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#version 400 compatibility

varying vec2 texCoords;
varying vec4 color;

void main() {
	texCoords = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    color = gl_Color;
    gl_Position = ftransform();
}