/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#if defined STAGE_VERTEX
	#define PROGRAM_WEATHER
	#include "/programs/gbuffers/gbuffers.vsh"

#elif defined STAGE_FRAGMENT

	/* RENDERTARGETS: 13 */

	layout (location = 0) out vec4 color;

	in vec2 texCoords;

	#include "/include/atmospherics/atmosphere.glsl"

	void main() {
		if(texture(colortex0, texCoords).a < 0.102) discard;

		color.rgb = vec3(dot(sampleSkyIlluminanceSimple() * 0.35, vec3(1.0 / 3.0)));
		color.a   = 0.3;
	}
#endif
