/********************************************************************************/
/*                                                                              */
/*    Noble Shaders                                                             */
/*    Copyright (C) 2025  Belmu                                                 */
/*                                                                              */
/*    This program is free software: you can redistribute it and/or modify      */
/*    it under the terms of the GNU General Public License as published by      */
/*    the Free Software Foundation, either version 3 of the License, or         */
/*    (at your option) any later version.                                       */
/*                                                                              */
/*    This program is distributed in the hope that it will be useful,           */
/*    but WITHOUT ANY WARRANTY; without even the implied warranty of            */
/*    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the             */
/*    GNU General Public License for more details.                              */
/*                                                                              */
/*    You should have received a copy of the GNU General Public License         */
/*    along with this program.  If not, see <https://www.gnu.org/licenses/>.    */
/*                                                                              */
/********************************************************************************/

#include "/settings.glsl"

#if defined BLOOM_DOWNSAMPLE_PASS
	const int lod = BLOOM_DOWNSAMPLE_PASS_INDEX;
#elif defined BLOOM_UPSAMPLE_PASS
	const int lod = BLOOM_UPSAMPLE_PASS_INDEX;
#endif

#if defined STAGE_VERTEX

	void main() {
		float lodFactor = exp2(-lod);
		vec2 tileCoords = gl_Vertex.xy * lodFactor * 0.5 + 1.0 - lodFactor;

		gl_Position = vec4(tileCoords * 2.0 - 1.0, 0.0, 1.0);
	}

#elif defined STAGE_FRAGMENT

	/* RENDERTARGETS: 3 */

	layout (location = 0) out vec4 bloom;

	const vec2 filterOffsets[12] = vec2[12](
		vec2( 1.0,  1.0),
		vec2(-1.0,  1.0),
		vec2( 1.0, -1.0),
		vec2(-1.0, -1.0),

		vec2( 0.0,  2.0),
		vec2( 0.0, -2.0),
		vec2( 2.0,  0.0),
		vec2(-2.0,  0.0),

		vec2( 2.0,  2.0),
		vec2(-2.0,  2.0),
		vec2( 2.0, -2.0),
		vec2(-2.0, -2.0)
	);

	const float filterWeights[3] = float[3](0.125, 0.0625, 0.03125);

	#include "/include/uniforms.glsl"

	#if defined BLOOM_DOWNSAMPLE_PASS
		#if BLOOM_DOWNSAMPLE_PASS_INDEX == 0
			#define BLOOM_SAMPLER MAIN_BUFFER
		#else
			#define BLOOM_SAMPLER SHADOWMAP_BUFFER
		#endif
	#elif defined BLOOM_UPSAMPLE_PASS
		#define BLOOM_SAMPLER SHADOWMAP_BUFFER

		#include "/include/utility/math.glsl"
		#include "/include/utility/sampling.glsl"
	#endif

	void main() {
		vec2 coords = gl_FragCoord.xy * texelSize;

		#if defined BLOOM_DOWNSAMPLE_PASS
			#if BLOOM_DOWNSAMPLE_PASS_INDEX == 0
				coords = coords * 2.0;
			#else
				coords = coords * 2.0 - 1.0;
			#endif
		#else
			coords = coords * 0.5 + 0.5;
		#endif

		#if defined BLOOM_DOWNSAMPLE_PASS

			bloom.rgb  = textureLod(BLOOM_SAMPLER, coords, 0).rgb * filterWeights[0];

			bloom.rgb += textureLod(BLOOM_SAMPLER, coords + filterOffsets[0]  * texelSize, 0).rgb * filterWeights[0];
			bloom.rgb += textureLod(BLOOM_SAMPLER, coords + filterOffsets[1]  * texelSize, 0).rgb * filterWeights[0];
			bloom.rgb += textureLod(BLOOM_SAMPLER, coords + filterOffsets[2]  * texelSize, 0).rgb * filterWeights[0];
			bloom.rgb += textureLod(BLOOM_SAMPLER, coords + filterOffsets[3]  * texelSize, 0).rgb * filterWeights[0];

			bloom.rgb += textureLod(BLOOM_SAMPLER, coords + filterOffsets[4]  * texelSize, 0).rgb * filterWeights[1];
			bloom.rgb += textureLod(BLOOM_SAMPLER, coords + filterOffsets[5]  * texelSize, 0).rgb * filterWeights[1];
			bloom.rgb += textureLod(BLOOM_SAMPLER, coords + filterOffsets[6]  * texelSize, 0).rgb * filterWeights[1];
			bloom.rgb += textureLod(BLOOM_SAMPLER, coords + filterOffsets[7]  * texelSize, 0).rgb * filterWeights[1];

			bloom.rgb += textureLod(BLOOM_SAMPLER, coords + filterOffsets[8]  * texelSize, 0).rgb * filterWeights[2];
			bloom.rgb += textureLod(BLOOM_SAMPLER, coords + filterOffsets[9]  * texelSize, 0).rgb * filterWeights[2];
			bloom.rgb += textureLod(BLOOM_SAMPLER, coords + filterOffsets[10] * texelSize, 0).rgb * filterWeights[2];
			bloom.rgb += textureLod(BLOOM_SAMPLER, coords + filterOffsets[11] * texelSize, 0).rgb * filterWeights[2];

			bloom.a = 0.0;

		#elif defined BLOOM_UPSAMPLE_PASS

			bloom.rgb = textureBicubic(BLOOM_SAMPLER, coords).rgb;
			bloom.a   = 1.0 / 9.0;

		#endif
	}
	
#endif
