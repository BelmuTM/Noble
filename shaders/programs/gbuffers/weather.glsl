/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#if defined STAGE_VERTEX
	#define PROGRAM_WEATHER
	#include "/programs/gbuffers/gbuffers.vsh"

#elif defined STAGE_FRAGMENT

	/* RENDERTARGETS: 4 */

	layout (location = 0) out vec4 color;

	in vec2 textureCoords;

	#include "/include/common.glsl"
	#include "/include/atmospherics/atmosphere.glsl"

	void main() {
		if(texture(tex, textureCoords).a < 0.102) discard;

		const float scatteringCoefficient   = 0.05;
		const vec3  attenuationCoefficients = vec3(0.20, 0.10, 0.04);

		color.rgb = evaluateUniformSkyIrradianceApproximation() * exp(-attenuationCoefficients) * scatteringCoefficient;
		color.a   = 0.5;
	}
#endif
