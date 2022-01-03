/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* DRAWBUFFERS:0 */

layout (location = 0) out vec4 color;

in vec2 texCoords;
in vec4 vertexColor;
uniform sampler2D colortex0;

void main() {
	color = texture(colortex0, texCoords) * color;
}
