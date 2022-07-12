/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#ifdef STAGE_VERTEX
	#define PROGRAM_WEATHER
	#include "/programs/gbuffers/gbuffers.vsh"

#elif defined STAGE_FRAGMENT
	/* RENDERTARGETS: 4 */

	layout (location = 0) out vec4 color;

	in vec2 texCoords;
	in vec4 vertexColor;

	#include "/include/common.glsl"

	void main() {
		vec4 albedoTex = texture(colortex0, texCoords);
			 albedoTex *= vertexColor;
		if(albedoTex.a < 0.102) discard;

		color = albedoTex;
	}
#endif
