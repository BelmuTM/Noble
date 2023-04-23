/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#if defined STAGE_VERTEX
	#define PROGRAM_WEATHER
	#include "/programs/gbuffers/gbuffers.vsh"

#elif defined STAGE_FRAGMENT

	/* RENDERTARGETS: 15 */

	layout (location = 0) out vec4 color;

	in vec2 texCoords;

	#include "/include/atmospherics/atmosphere.glsl"

	void main() {
		if(texture(tex, texCoords).a < 0.102) discard;

		const float scatteringCoefficient   = 0.05;
		const vec3  attenuationCoefficients = vec3(0.20, 0.10, 0.04);
		const float density 				= 2.0;

		color.rgb = sampleSkyIlluminanceSimple() * exp(-attenuationCoefficients * density) * scatteringCoefficient;
		color.a   = 0.3;
	}
#endif
