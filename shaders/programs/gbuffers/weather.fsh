/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

in vec2 texCoords;
uniform sampler2D colortex0;

void main() {
	vec4 albedoTex = texture(colortex0, texCoords);
	if(albedoTex.a < 0.102) discard;
}
