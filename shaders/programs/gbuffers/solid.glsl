/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#if defined STAGE_VERTEX
	#include "/programs/gbuffers/gbuffers.vsh"

#elif defined STAGE_FRAGMENT
	/* RENDERTARGETS: 1 */

	layout (location = 0) out uvec4 dataBuffer;

	flat in int blockId;
	in vec2 texCoords;
	in vec2 lmCoords;
	in vec3 viewPos;
	in vec3 geoNormal;
	in vec4 vertexColor;
	in mat3 TBN;

	#define STAGE_FRAGMENT

	#ifdef PROGRAM_ENTITY
		uniform vec4 entityColor;
	#endif

	#include "/include/common.glsl"

	void main() {
		vec4 albedoTex   = texture(colortex0, texCoords);
		vec4 normalTex   = texture(normals,   texCoords);
		vec4 specularTex = texture(specular,  texCoords);

		if(albedoTex.a < 0.102) discard;

		albedoTex *= vertexColor;

		#ifdef PROGRAM_ENTITY
			albedoTex.rgb = mix(albedoTex.rgb, entityColor.rgb, entityColor.a);
		#endif

		#if WHITE_WORLD == 1
	    	albedoTex.rgb = vec3(1.0);
    	#endif

		float F0 		 = specularTex.y;
		float ao 		 = all(greaterThan(geoNormal, vec3(0.0))) ? normalTex.z : 1.0; // Thanks Kneemund for the nametag fix
		float roughness  = clamp01(hardCodedRoughness != 0.0 ? hardCodedRoughness : 1.0 - specularTex.x);
		float emission   = specularTex.w * maxVal8 < 254.5 ? specularTex.w : 0.0;
		float subsurface = clamp01(specularTex.z * (maxVal8 / 190.0) - (65.0 / 190.0));
		float porosity   = clamp01(specularTex.z * (maxVal8 / 64.0));

		vec3 normal;
		#if !defined PROGRAM_BLOCK
			normal.xy = normalTex.xy * 2.0 - 1.0;
			normal.z  = sqrt(1.0 - dot(normal.xy, normal.xy));
			normal    = TBN * normal;
		#else
			normal = geoNormal;
		#endif

		#ifdef PROGRAM_TERRAIN
			#if RAIN_PUDDLES == 1
				if(F0 * maxVal8 <= 229.5) {
					float puddle  = voronoise((viewToWorld(viewPos).xz * 0.5 + 0.5) * (1.0 - RAIN_PUDDLES_SIZE), 0, 1);
		  	  	  	  	  puddle *= pow2(quintic(EPS, 1.0, lmCoords.y));
	  				  	  puddle *= (1.0 - porosity);
			  	  	  	  puddle *= rainStrength;
			  	  	  	  puddle *= quintic(0.2, 0.9, normal.y);
	
					F0        = clamp01(mix(F0, RAIN_PUDDLES_STRENGTH, puddle));
					roughness = clamp01(mix(roughness, 0.0, puddle));
					normal    = mix(normal, geoNormal, puddle);
				}
			#endif
		#endif

		vec2 encNormal = encodeUnitVector(normalize(normal));
	
		dataBuffer.x = packUnorm4x8(vec4(roughness, (blockId + 0.25) / maxVal8, clamp01(lmCoords)));
		dataBuffer.y = packUnorm4x8(vec4(ao, emission, F0, subsurface));
		dataBuffer.z = (uint(albedoTex.r * maxVal8) << 16u) | (uint(albedoTex.g * maxVal8) << 8u) | uint(albedoTex.b * maxVal8);
		dataBuffer.w = (uint(encNormal.x * maxVal16) << 16u) | uint(encNormal.y * maxVal16);
	}
#endif
