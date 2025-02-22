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

const float lodFactor = exp2(-lod); 

#if defined STAGE_VERTEX

	void main() {
		vec2 tileCoords = gl_Vertex.xy * lodFactor * 0.5 + 1.0 - lodFactor;

		gl_Position = vec4(tileCoords * 2.0 - 1.0, 0.0, 1.0);
	}

#elif defined STAGE_FRAGMENT

	/* RENDERTARGETS: 3 */

	layout (location = 0) out vec4 bloom;

	#include "/include/uniforms.glsl"

	#if defined BLOOM_DOWNSAMPLE_PASS

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
	#include "/include/utility/math.glsl"

	#if defined BLOOM_DOWNSAMPLE_PASS
		#if BLOOM_DOWNSAMPLE_PASS_INDEX == 0
			#define BLOOM_SAMPLER MAIN_BUFFER
		#else
			#define BLOOM_SAMPLER SHADOWMAP_BUFFER
		#endif

	#elif defined BLOOM_UPSAMPLE_PASS

		#define BLOOM_SAMPLER SHADOWMAP_BUFFER

		#include "/include/utility/sampling.glsl"

		float tileWeight(int lod) {
			return exp2(-0.5 * lod);
		}
	#endif

	#if defined BLOOM_DOWNSAMPLE_PASS

		vec3 sampleBloomBuffer(vec2 coords) {
			#if BLOOM_DOWNSAMPLE_PASS_INDEX == 0
				return logLuvDecode(textureLod(BLOOM_SAMPLER, coords, 0));
			#else
				return textureLod(BLOOM_SAMPLER, coords, 0).rgb;
			#endif
		}

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

			bloom.rgb  = sampleBloomBuffer(coords).rgb * filterWeights[0];

			bloom.rgb += sampleBloomBuffer(coords + filterOffsets[0]  * texelSize) * filterWeights[0];
			bloom.rgb += sampleBloomBuffer(coords + filterOffsets[1]  * texelSize) * filterWeights[0];
			bloom.rgb += sampleBloomBuffer(coords + filterOffsets[2]  * texelSize) * filterWeights[0];
			bloom.rgb += sampleBloomBuffer(coords + filterOffsets[3]  * texelSize) * filterWeights[0];

			bloom.rgb += sampleBloomBuffer(coords + filterOffsets[4]  * texelSize) * filterWeights[1];
			bloom.rgb += sampleBloomBuffer(coords + filterOffsets[5]  * texelSize) * filterWeights[1];
			bloom.rgb += sampleBloomBuffer(coords + filterOffsets[6]  * texelSize) * filterWeights[1];
			bloom.rgb += sampleBloomBuffer(coords + filterOffsets[7]  * texelSize) * filterWeights[1];

			bloom.rgb += sampleBloomBuffer(coords + filterOffsets[8]  * texelSize) * filterWeights[2];
			bloom.rgb += sampleBloomBuffer(coords + filterOffsets[9]  * texelSize) * filterWeights[2];
			bloom.rgb += sampleBloomBuffer(coords + filterOffsets[10] * texelSize) * filterWeights[2];
			bloom.rgb += sampleBloomBuffer(coords + filterOffsets[11] * texelSize) * filterWeights[2];

			bloom.a = 0.0;

		#elif defined BLOOM_UPSAMPLE_PASS

			float normalization = 0.0;
			for(int tile = 0; tile < 9; tile++) normalization += tileWeight(tile);
			normalization = 1.0 / normalization;

			bloom.rgb = textureBicubic(BLOOM_SAMPLER, coords).rgb;
			bloom.a   = tileWeight(BLOOM_UPSAMPLE_PASS_INDEX) * normalization;

			#if BLOOM_UPSAMPLE_PASS_INDEX == 7
				bloom.rgb *= tileWeight(BLOOM_UPSAMPLE_PASS_INDEX + 1) * normalization;
			#endif

		#endif
	}
	
#endif
