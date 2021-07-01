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

uniform sampler2D colortex0;

const float rainBrightness = 2.5;
void main() {
    vec4 Albedo = texture2D(colortex0, texCoords) * color;
    Albedo /= rainBrightness;

    /*DRAWBUFFERS:08*/
    gl_FragData[0] = Albedo;
    gl_FragData[3] = vec4(1.0);
}
