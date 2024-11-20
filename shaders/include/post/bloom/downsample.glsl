/***********************************************/
/*          Copyright (C) 2024 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/settings.glsl"

#if BLOOM == 0
    #include "/programs/discard.glsl"
#else

	const float bloomScales[6] = float[6](
		0.500000,
		0.250000,
		0.125000,
		0.062500,
		0.031250,
		0.015625
	);

	const vec2 bloomOffsets[6] = vec2[6](
		vec2(0.0000, 0.0000),
		vec2(0.0000, 0.5010),
		vec2(0.2510, 0.5010),
		vec2(0.2510, 0.6280),
		vec2(0.3145, 0.6280),
		vec2(0.3150, 0.6618)
	);

    #if defined STAGE_VERTEX
    
        out vec2 textureCoords;

        void main() {
			vec2 tileCoords = gl_Vertex.xy * bloomScales[BLOOM_PASS_INDEX] + bloomOffsets[BLOOM_PASS_INDEX];

            gl_Position   = vec4(tileCoords * 2.0 - 1.0, 0.0, 1.0);
            textureCoords = gl_Vertex.xy;
        }

    #elif defined STAGE_FRAGMENT

		/* RENDERTARGETS: 3 */

		layout (location = 0) out vec3 bloom;

		in vec2 textureCoords;

		#include "/include/uniforms.glsl"

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

		#if BLOOM_PASS_INDEX == 0
			const float scale  = 1.0;
			const vec2  offset = vec2(0.0);
			#define BLOOM_SAMPLER MAIN_BUFFER
		#else
			const float scale  = bloomScales [BLOOM_PASS_INDEX - 1];
			const vec2  offset = bloomOffsets[BLOOM_PASS_INDEX - 1];
			#define BLOOM_SAMPLER SHADOWMAP_BUFFER
		#endif

		void main() {
			vec2 coords = textureCoords * scale + offset;

			bloom  = textureLod(BLOOM_SAMPLER, coords, 0).rgb * filterWeights[0];

			bloom += textureLod(BLOOM_SAMPLER, coords + filterOffsets[0]  * texelSize, 0).rgb * filterWeights[0];
			bloom += textureLod(BLOOM_SAMPLER, coords + filterOffsets[1]  * texelSize, 0).rgb * filterWeights[0];
			bloom += textureLod(BLOOM_SAMPLER, coords + filterOffsets[2]  * texelSize, 0).rgb * filterWeights[0];
			bloom += textureLod(BLOOM_SAMPLER, coords + filterOffsets[3]  * texelSize, 0).rgb * filterWeights[0];

			bloom += textureLod(BLOOM_SAMPLER, coords + filterOffsets[4]  * texelSize, 0).rgb * filterWeights[1];
			bloom += textureLod(BLOOM_SAMPLER, coords + filterOffsets[5]  * texelSize, 0).rgb * filterWeights[1];
			bloom += textureLod(BLOOM_SAMPLER, coords + filterOffsets[6]  * texelSize, 0).rgb * filterWeights[1];
			bloom += textureLod(BLOOM_SAMPLER, coords + filterOffsets[7]  * texelSize, 0).rgb * filterWeights[1];

			bloom += textureLod(BLOOM_SAMPLER, coords + filterOffsets[8]  * texelSize, 0).rgb * filterWeights[2];
			bloom += textureLod(BLOOM_SAMPLER, coords + filterOffsets[9]  * texelSize, 0).rgb * filterWeights[2];
			bloom += textureLod(BLOOM_SAMPLER, coords + filterOffsets[10] * texelSize, 0).rgb * filterWeights[2];
			bloom += textureLod(BLOOM_SAMPLER, coords + filterOffsets[11] * texelSize, 0).rgb * filterWeights[2];
		}
		
	#endif
#endif
