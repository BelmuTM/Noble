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
				vec2 puddleCoords = (viewToWorld(viewPos).xz * 0.5 + 0.5) * (1.0 - RAIN_PUDDLES_SIZE);

				float puddle  = quintic(0.0, 1.0, FBM(puddleCoords, 1, 1.3) * 0.5 + 0.5);
		  	  	  	  puddle *= pow2(quintic(0.0, 1.0, lmCoords.y));
	  				  puddle *= (1.0 - porosity);
			  	  	  puddle *= wetness;
			  	  	  puddle *= quintic(0.89, 0.99, normal.y);
					  puddle  = clamp01(puddle);
	
				roughness = mix(roughness, 0.0,    puddle);
				normal    = mix(normal, geoNormal, puddle);
			#endif
		#endif

		        normal = normalize(normal);
		vec2 encNormal = encodeUnitVector(normal);

		vec2 lightmapCoords = lmCoords;

		#if DIRECTIONAL_LIGHTMAP == 1 && GI == 0
			vec3 scenePos    = viewToScene(viewPos);
			vec2 dFdLmCoords = vec2(dFdx(lmCoords.x), dFdy(lmCoords.x));
			vec3 dirLmCoords = dFdx(scenePos) * dFdLmCoords.x + dFdy(scenePos) * dFdLmCoords.y;

			// Dot product's range shifting and invalid direction handling ideas from ninjamike1211#5424
			if(length(dFdLmCoords) < 1e-6) { lightmapCoords.x *= clamp01(dot(TBN * vec3(0.0, 0.0, 0.9), normal));                }
			else                           { lightmapCoords.x *= clamp01(dot(normalize(dirLmCoords), normal) + 0.8) * 0.8 + 0.2; }
		#endif

		vec3 data0 = vec3(roughness, clamp01(lightmapCoords));
		vec4 data1 = vec4(ao, emission, F0, subsurface);

		// I bet you've never seen a cleaner data packing implementation huh?? SAY IT!!!!
		uvec4 shiftedData0  = uvec4(round(data0         * vec3(maxVal8, 511.0, 511.0)), blockId) << uvec4(0, 8, 17, 26);
		uvec4 shiftedData1  = uvec4(round(data1         * maxVal8))                              << uvec4(0, 8, 17, 26);
		uvec3 shiftedAlbedo = uvec3(round(albedoTex.rgb * vec3(2047.0, 1023.0, 2047.0)))         << uvec3(0, 11, 21);
		uvec2 shiftedNormal = uvec2(round(encNormal     * maxVal16))                             << uvec2(0, 16);

		data.x = shiftedData0.x  | shiftedData0.y  | shiftedData0.z | shiftedData0.w;
		data.y = shiftedData1.x  | shiftedData1.y  | shiftedData1.z | shiftedData1.w;
		data.z = shiftedAlbedo.x | shiftedAlbedo.y | shiftedAlbedo.z;
		data.w = shiftedNormal.x | shiftedNormal.y;

		geometricNormal = geoNormal;
	}
#endif
