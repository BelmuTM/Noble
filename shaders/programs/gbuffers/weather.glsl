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

	/* RENDERTARGETS: 13 */

	layout (location = 0) out vec4 color;

	in vec2 texCoords;
	in vec3 viewPos;
	in vec4 vertexColor;

	#include "/include/atmospherics/atmosphere.glsl"

	void main() {
		vec4 albedoTex  = texture(tex, texCoords);
		     albedoTex *= vertexColor;

		if(albedoTex.a < 0.102) discard;

		color.rgb = albedoTex.rgb * sampleSkyIlluminanceSimple() * 0.2;
		color.a   = 0.5;
	}
#endif
