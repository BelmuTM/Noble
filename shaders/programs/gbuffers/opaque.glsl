/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#ifdef STAGE_VERTEX
	#include "/programs/gbuffers/gbuffers.vsh"

#elif defined STAGE_FRAGMENT

	/* RENDERTARGETS: 1,2 */

	layout (location = 0) out uvec4 data;
	layout (location = 1) out vec3 geometricNormal;

	flat in int blockId;
	in vec2 texCoords;
	in vec2 lmCoords;
	in vec3 viewPos;
	in vec3 geoNormal;
	in vec4 vertexColor;
	in mat3 TBN;

	#include "/include/common.glsl"

	#ifdef PROGRAM_ENTITY
		uniform vec4 entityColor;
	#endif

	void main() {
		vec4 albedoTex   = texture(colortex0, texCoords);
		vec4 normalTex   = texture(normals,   texCoords);
		vec4 specularTex = texture(specular,  texCoords);

		if(albedoTex.a < 0.102) discard;

		albedoTex *= vertexColor;

		float F0 		 = specularTex.y;
		float ao 		 = normalTex.z;
		float roughness  = clamp01(hardCodedRoughness != 0.0 ? hardCodedRoughness : 1.0 - specularTex.x);
		float emission   = specularTex.w * maxVal8 < 254.5 ? specularTex.w : 0.0;
		float subsurface = clamp01(specularTex.z * (maxVal8 / 190.0) - (65.0 / 190.0));
		float porosity   = clamp01(specularTex.z * (maxVal8 / 64.0));

		#ifdef PROGRAM_ENTITY
			albedoTex.rgb = mix(albedoTex.rgb, entityColor.rgb, entityColor.a);

			ao = all(lessThanEqual(normalTex.rgb, vec3(EPS))) ? 1.0 : ao;
		#endif

		#if WHITE_WORLD == 1
	    	albedoTex.rgb = vec3(1.0);
    	#endif

		#ifdef PROGRAM_BEACONBEAM
			if(albedoTex.a <= 1.0 - EPS) discard;
			emission = 1.0;
		#endif

		vec3 normal = geoNormal;
		#ifndef PROGRAM_BLOCK
			if(all(greaterThan(normalTex, vec4(EPS)))) {
				normal.xy = normalTex.xy * 2.0 - 1.0;
				normal.z  = sqrt(1.0 - dot(normal.xy, normal.xy));
				normal    = TBN * normal;
			}
		#endif

		#ifdef PROGRAM_TERRAIN
			#if RAIN_PUDDLES == 1
				if(F0 * maxVal8 <= 229.5) {
					vec2 puddleCoords = (viewToWorld(viewPos).xz * 0.5 + 0.5) * (1.0 - RAIN_PUDDLES_SIZE);

					float puddle  = quintic(0.0, 1.0, FBM(puddleCoords, 1, 1.3) * 0.5 + 0.5);
		  	  	  	  	  puddle *= pow2(quintic(0.0, 1.0, lmCoords.y));
	  				  	  puddle *= (1.0 - porosity);
			  	  	  	  puddle *= wetness;
			  	  	  	  puddle *= quintic(0.89, 0.99, normal.y);
						  puddle  = clamp01(puddle);
	
					F0        = mix(F0, waterF0,       puddle);
					roughness = mix(roughness, 0.0,    puddle);
					normal    = mix(normal, geoNormal, puddle);
				}
			#endif
		#endif

		vec2 encNormal = encodeUnitVector(normalize(normal));
	
		data.x = packUnorm4x8(vec4(roughness, (blockId + 0.25) * rcp(maxVal8), max0(lmCoords)));
		data.y = packUnorm4x8(vec4(ao, emission, F0, subsurface));
		data.z = (uint(albedoTex.r * maxVal8) << 16u) | (uint(albedoTex.g * maxVal8) << 8u) | uint(albedoTex.b * maxVal8);
		data.w = (uint(encNormal.x * maxVal16) << 16u) | uint(encNormal.y * maxVal16);

		geometricNormal = geoNormal;
	}
#endif
