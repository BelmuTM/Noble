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

	/* RENDERTARGETS: 1,3 */

	layout (location = 0) out uvec4 data0;
	layout (location = 1) out vec4  data1;

	flat in int blockId;
	in vec2 texCoords;
	in vec2 lmCoords;
	in vec2 texSize;
	in vec2 botLeft;
	in vec3 viewPos;
	in vec4 vertexColor;
	in mat3 TBN;

	#include "/include/common.glsl"

	#ifdef PROGRAM_ENTITY
		uniform vec4 entityColor;
	#endif

	#if POM > 0 && defined PROGRAM_TERRAIN
		/*
			CREDITS:
			Null:      https://github.com/null511 - null511#3026
			NinjaMike:                            - ninjamike1211#5424
			
			Thanks to them for their help!
		*/

		const float layerHeight = 1.0 / float(POM_LAYERS);

		void wrapCoordinates(inout vec2 coords) { coords -= floor((coords - botLeft) / texSize) * texSize; }

		vec2 localToAtlas(vec2 localCoords) { return (fract(localCoords) * texSize + botLeft); }
		vec2 atlasToLocal(vec2 atlasCoords) { return (atlasCoords - botLeft) / texSize;        }

		#if POM == 1
			float sampleHeightMap(inout vec2 coords, mat2 texDeriv) {
				wrapCoordinates(coords);
				return 1.0 - textureGrad(normals, coords, texDeriv[0], texDeriv[1]).a;
			}
		#else
			float sampleHeightMap(inout vec2 coords, mat2 texDeriv) {
				wrapCoordinates(coords);

				vec2 uv[4];
				vec2 f = getLinearCoords(atlasToLocal(coords), texSize * atlasSize, uv);

				uv[0] = localToAtlas(uv[0]);
				uv[1] = localToAtlas(uv[1]);
				uv[2] = localToAtlas(uv[2]);
				uv[3] = localToAtlas(uv[3]);

    			return 1.0 - textureGradLinear(normals, uv, texDeriv, f, 3);
			}
		#endif

    	vec2 parallaxMapping(vec3 viewPos, mat2 texDeriv, inout float height, out vec2 shadowCoords) {
			vec3 tangentDir       = normalize(viewToScene(viewPos)) * TBN;
        	float currLayerHeight = 0.0;

        	vec2 P           = (tangentDir.xy / tangentDir.z) * POM_DEPTH * texSize;
        	vec2 deltaCoords = P * layerHeight;

        	vec2  currCoords     = texCoords;
        	float currFragHeight = sampleHeightMap(currCoords, texDeriv);

        	for(int i = 0; i < POM_LAYERS && currLayerHeight < currFragHeight; i++) {
            	currCoords      -= deltaCoords;
            	currFragHeight   = sampleHeightMap(currCoords, texDeriv);
            	currLayerHeight += layerHeight;
        	}

			vec2 prevCoords = currCoords + deltaCoords;
			   shadowCoords = prevCoords;

			#if POM == 1
				height = currLayerHeight;
			#else
				float afterHeight  = currFragHeight - currLayerHeight;
				float beforeHeight = sampleHeightMap(prevCoords, texDeriv) - currLayerHeight + layerHeight;
				float weight       = afterHeight / (afterHeight - beforeHeight);

				height = 0.0;

				return mix(currCoords, prevCoords, weight);
			#endif

 			return currCoords;
    	}

		float parallaxShadowing(vec2 parallaxCoords, float height, mat2 texDeriv) {
			vec3 tangentDir       = shadowLightVector * TBN;
        	float currLayerHeight = height;

        	vec2 P           = (tangentDir.xy / tangentDir.z) * POM_DEPTH * texSize;
        	vec2 deltaCoords = P * layerHeight;

        	vec2  currCoords     = parallaxCoords;
        	float currFragHeight = 1.0;

			float shadow = 1.0;

        	for(int i = 0; i < POM_LAYERS; i++) {
				if(currLayerHeight >= currFragHeight) {
					shadow = 0.0; break;
				}
            	currCoords      += deltaCoords;
            	currFragHeight   = sampleHeightMap(currCoords, texDeriv);
            	currLayerHeight -= layerHeight;
        	}
 			return shadow;
    	}
	#endif

	void main() {
		#if defined PROGRAM_HAND && DISCARD_HAND == 1
			discard;
		#endif

		float pomSelfShadowing = 1.0;

		#if POM > 0 && defined PROGRAM_TERRAIN
			mat2 texDeriv = mat2(dFdx(texCoords), dFdy(texCoords));
			float height  = 1.0;
			vec2 shadowCoords;

			vec2 coords = parallaxMapping(viewPos, texDeriv, height, shadowCoords);

			pomSelfShadowing = parallaxShadowing(shadowCoords, height, texDeriv);
			if(clamp01(coords) != coords) discard;
		#else
			vec2 coords = texCoords;
		#endif

		vec4 albedoTex = texture(colortex0, coords);
		if(albedoTex.a < 0.102) discard;

		vec4 normalTex = texture(normals,  coords);

		#if !defined PROGRAM_TEXTURED
			vec4 specularTex = texture(specular, coords);
		#else
			vec4 specularTex = vec4(0.0);
		#endif

		albedoTex *= vertexColor;

		float F0 		 = specularTex.y;
		float ao 		 = normalTex.z;
		float roughness  = clamp01(hardCodedRoughness != 0.0 ? hardCodedRoughness : 1.0 - specularTex.x);
		float emission   = specularTex.w * maxVal8 < 254.5 ? specularTex.w : 0.0;
		float subsurface = clamp01(specularTex.z * (maxVal8 / 190.0) - (65.0 / 190.0));

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

		#if HARDCODED_EMISSION == 1
			if(blockId >= 5 && blockId < 8 && emission <= EPS) emission = HARDCODED_EMISSION_VAL;
		#endif

		vec3 normal = TBN[2];
		#ifndef PROGRAM_BLOCK
			if(all(greaterThan(normalTex, vec4(EPS)))) {
				normal.xy = normalTex.xy * 2.0 - 1.0;
				normal.z  = sqrt(1.0 - dot(normal.xy, normal.xy));
				normal    = TBN * normal;
			}
		#endif

		#ifdef PROGRAM_TERRAIN
			#if RAIN_PUDDLES == 1
				if(wetness > 0.0) {
					float porosity    = clamp01(specularTex.z * (maxVal8 / 64.0));
					vec2 puddleCoords = (viewToWorld(viewPos).xz * 0.5 + 0.5) * (1.0 - RAIN_PUDDLES_SIZE);

					float puddle  = quintic(0.0, 1.0, FBM(puddleCoords, 1, 1.3) * 0.5 + 0.5);
		  	  	  		  puddle *= pow2(quintic(0.0, 1.0, lmCoords.y));
	  					  puddle *= (1.0 - porosity);
			  	  		  puddle *= wetness;
			  	  		  puddle *= quintic(0.89, 0.99, TBN[2].y);
						  puddle  = clamp01(puddle);
	
					F0        = clamp(F0 + waterF0 * puddle, 0.0, mix(1.0, 229.5 * rcpMaxVal8, float(F0 * maxVal8 <= 229.5)));
					roughness = mix(roughness, 0.0, puddle);
					normal    = mix(normal, TBN[2], puddle);
				}
			#endif
		#endif

		        normal = normalize(normal);
		vec2 encNormal = encodeUnitVector(normal);

		vec2 lightmapCoords = lmCoords;

		#if DIRECTIONAL_LIGHTMAP == 1 && GI == 0
			vec3 scenePos    = viewToScene(viewPos);
			vec3 dirLmCoords = dFdx(scenePos) * dFdx(lmCoords.x) + dFdy(scenePos) * dFdy(lmCoords.x);

			// Dot product's range shifting from ninjamike1211#5424
			lightmapCoords.x *= clamp01(dot(normalize(dirLmCoords), normal) + 0.8) * 0.8 + 0.2;
		#endif

		vec3 labPbrData0 = vec3(roughness, clamp01(lightmapCoords));
		vec4 labPbrData1 = vec4(ao, emission, F0, subsurface);

		// I bet you've never seen a cleaner data packing implementation huh?? SAY IT!!!!
		uvec4 shiftedData0  = uvec4(round(labPbrData0   * vec3(maxVal8, 511.0, 511.0)), blockId) << uvec4(0, 8, 17, 26);
		uvec4 shiftedData1  = uvec4(round(labPbrData1   * maxVal8))                              << uvec4(0, 8, 16, 24);
		uvec3 shiftedAlbedo = uvec3(round(albedoTex.rgb * vec3(2047.0, 1023.0, 2047.0)))         << uvec3(0, 11, 21);
		uvec2 shiftedNormal = uvec2(round(encNormal     * maxVal16))                             << uvec2(0, 16);

		data0.x = shiftedData0.x  | shiftedData0.y  | shiftedData0.z | shiftedData0.w;
		data0.y = shiftedData1.x  | shiftedData1.y  | shiftedData1.z | shiftedData1.w;
		data0.z = shiftedAlbedo.x | shiftedAlbedo.y | shiftedAlbedo.z;
		data0.w = shiftedNormal.x | shiftedNormal.y;

		data1.xyz = TBN[2];
		data1.w   = pomSelfShadowing;
	}
#endif
