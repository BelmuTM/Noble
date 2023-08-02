/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/include/taau_scale.glsl"
#include "/include/common.glsl"

#if defined STAGE_VERTEX
	#define attribute in
	attribute vec4 at_tangent;
	attribute vec3 mc_Entity;
	attribute vec2 mc_midTexCoord;

	flat out int blockId;
	out vec2 textureCoords;
	out vec2 lightmapCoords;
	out vec2 texSize;
	out vec2 botLeft;
	out vec3 viewPosition;
	out vec4 vertexColor;
	out mat3 tbn;

	#include "/include/vertex/animation.glsl"

	void main() {
		#if defined PROGRAM_HAND && RENDER_MODE == 1
			gl_Position = vec4(1.0);
			return;
		#endif

		textureCoords  = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
		lightmapCoords = gl_MultiTexCoord1.xy * rcp(240.0);
		vertexColor    = gl_Color;

		#if defined PROGRAM_ENTITY
			// Thanks Niemand#1929 for the nametag fix
			if(vertexColor.a >= 0.24 && vertexColor.a < 0.255) {
				gl_Position = vec4(10.0, 10.0, 10.0, 1.0);
				return;
			}
		#endif

		#if POM > 0 && defined PROGRAM_TERRAIN
			vec2 halfSize = abs(textureCoords - mc_midTexCoord);
			texSize       = halfSize * 2.0;
			botLeft       = mc_midTexCoord - halfSize;
		#endif

    	viewPosition = transform(gl_ModelViewMatrix, gl_Vertex.xyz);

    	tbn[2] = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * gl_Normal);
    	tbn[0] = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * at_tangent.xyz);
		tbn[1] = cross(tbn[0], tbn[2]) * sign(at_tangent.w);

		blockId = int((mc_Entity.x - 1000.0) + 0.25);
	
		vec3 worldPosition = transform(gbufferModelViewInverse, viewPosition);

		#if RENDER_MODE == 0
			#if defined PROGRAM_TERRAIN && WAVING_PLANTS == 1
				animate(worldPosition, textureCoords.y < mc_midTexCoord.y, getSkylightFalloff(lightmapCoords.y));
			#endif

			#if defined PROGRAM_WEATHER
				worldPosition.xz += RAIN_DIRECTION * worldPosition.y;
			#endif
		#endif
	
		gl_Position    = transform(gbufferModelView, worldPosition).xyzz * diagonal4(gl_ProjectionMatrix) + gl_ProjectionMatrix[3];
		gl_Position.xy = gl_Position.xy * RENDER_SCALE + (RENDER_SCALE - 1.0) * gl_Position.w;

		#if TAA == 1 && EIGHT_BITS_FILTER == 0
			gl_Position.xy += taaJitter(gl_Position);
		#endif
	}

#elif defined STAGE_FRAGMENT

	/* RENDERTARGETS: 1,3 */

	layout (location = 0) out uvec4 data0;
	layout (location = 1) out vec2  data1;

	flat in int blockId;
	in vec2 textureCoords;
	in vec2 lightmapCoords;
	in vec2 texSize;
	in vec2 botLeft;
	in vec3 viewPosition;
	in vec4 vertexColor;
	in mat3 tbn;

	#if defined PROGRAM_ENTITY
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
			#include "/include/utility/sampling.glsl"

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

    	vec2 parallaxMapping(vec3 viewPosition, mat2 texDeriv, inout float height, out vec2 shadowCoords) {
			vec3 tangentDirection = normalize(viewToScene(viewPosition)) * tbn;
        	float currLayerHeight = 0.0;

        	vec2 scaledVector = (tangentDirection.xy / tangentDirection.z) * POM_DEPTH * texSize;
        	vec2 offset       = scaledVector * layerHeight;

        	vec2  currCoords     = textureCoords;
        	float currFragHeight = sampleHeightMap(currCoords, texDeriv);

        	for(int i = 0; i < POM_LAYERS && currLayerHeight < currFragHeight; i++) {
            	currCoords      -= offset;
            	currFragHeight   = sampleHeightMap(currCoords, texDeriv);
            	currLayerHeight += layerHeight;
        	}

			vec2 prevCoords = currCoords + offset;
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
			vec3  tangentDir      = shadowLightVector * tbn;
        	float currLayerHeight = height;

        	vec2 scaledVector = (tangentDir.xy / tangentDir.z) * POM_DEPTH * texSize;
        	vec2 offset 	  = scaledVector * layerHeight;

        	vec2  currCoords     = parallaxCoords;
        	float currFragHeight = 1.0;

			float disocclusion = 1.0;

        	for(int i = 0; i < POM_LAYERS; i++) {
				if(currLayerHeight >= currFragHeight) {
					disocclusion = 0.0; break;
				}
            	currCoords      += offset;
            	currFragHeight   = sampleHeightMap(currCoords, texDeriv);
            	currLayerHeight -= layerHeight;
        	}
 			return disocclusion;
    	}
	#endif

	vec2 computeLightmap(vec3 normal) {

		#if DIRECTIONAL_LIGHTMAP == 1 && GI == 0
			// Thanks ninjamike1211 for the help
			vec2 lightmap 	   = lightmapCoords;
			vec3 scenePosition = viewToScene(viewPosition);

			vec2 blocklightDeriv = vec2(dFdx(lightmap.x), dFdy(lightmap.x));
			vec2 skylightDeriv   = vec2(dFdx(lightmap.y), dFdy(lightmap.y));

			vec3 lightmapVectorX = dFdx(scenePosition) * blocklightDeriv.x + dFdy(scenePosition) * blocklightDeriv.y;
				 lightmap.x     *= saturate(dot(normalize(lightmapVectorX), normal) + 0.8) * 0.8 + 0.2;

    		lightmap.y *= saturate(dot(vec3(0.0, 1.0, 0.0), normal) + 0.8) * 0.2 + 0.8;
		
			return lightmap;
		#endif
		return lightmapCoords;
	}

	void main() {
		vec2 fragCoords = gl_FragCoord.xy * pixelSize / RENDER_SCALE;
		if(saturate(fragCoords) != fragCoords) discard;

		#if defined PROGRAM_HAND && RENDER_MODE == 1
			discard;
		#endif

		float parallaxSelfShadowing = 1.0;

		#if POM > 0 && defined PROGRAM_TERRAIN
			vec2 coords = textureCoords;

			if(texture(normals, textureCoords).a < 1.0 - EPS) {
				mat2 texDeriv = mat2(dFdx(textureCoords), dFdy(textureCoords));
				float height  = 1.0;
				vec2 shadowCoords;

				coords 				  = parallaxMapping(viewPosition, texDeriv, height, shadowCoords);
				parallaxSelfShadowing = parallaxShadowing(shadowCoords, height, texDeriv);
			}

			if(saturate(coords) != coords) discard;
		#else
			vec2 coords = textureCoords;
		#endif

		vec4 albedoTex = texture(tex, coords);
		if(albedoTex.a < 0.102) discard;

		vec4 normalTex = texture(normals, coords);

		#if !defined PROGRAM_TEXTURED
			vec4 specularTex = texture(specular, coords);
		#else
			vec4 specularTex = vec4(0.0);
		#endif

		albedoTex *= vertexColor;

		vec2 lightmap = lightmapCoords;

		float F0 		 = specularTex.y;
		float ao 		 = normalTex.z;
		float roughness  = saturate(hardcodedRoughness != 0.0 ? hardcodedRoughness : 1.0 - specularTex.x);
		float emission   = specularTex.w * maxVal8 < 254.5 ? specularTex.w : 0.0;
		float subsurface = saturate(specularTex.z * (maxVal8 / 190.0) - (65.0 / 190.0));

		#if defined PROGRAM_ENTITY
			albedoTex.rgb = mix(albedoTex.rgb, entityColor.rgb, entityColor.a);
			
			ao = all(lessThanEqual(normalTex.rgb, vec3(EPS))) ? 1.0 : ao;
		#endif

		#if WHITE_WORLD == 1
	    	albedoTex.rgb = vec3(1.0);
    	#endif

		#if defined PROGRAM_BEACONBEAM
			if(albedoTex.a <= 1.0 - EPS) discard;
			emission = 1.0;
		#endif

		#if HARDCODED_EMISSION == 1
			if(blockId >= LAVA_ID && blockId < SSS_ID && emission <= EPS) emission = HARDCODED_EMISSION_VAL;
		#endif

		vec3 normal = tbn[2];
		#if !defined PROGRAM_BLOCK
			if(all(greaterThan(normalTex, vec4(EPS)))) {
				normal.xy = normalTex.xy * 2.0 - 1.0;
				normal.z  = sqrt(1.0 - saturate(dot(normal.xy, normal.xy)));
				normal    = tbn * normal;

				if(any(greaterThan(normalTex.xy, vec2(1e-3)))) lightmap = computeLightmap(normalize(normal));
			}
		#endif

		#if defined PROGRAM_SPIDEREYES
			lightmap = vec2(lightmapCoords.x, 0.0);
		#endif

		#if defined PROGRAM_TERRAIN && RAIN_PUDDLES == 1
			if(wetness > 0.0 && isEyeInWater == 0) {
				float porosity    = saturate(specularTex.z * (maxVal8 / 64.0));
				vec2 puddleCoords = (viewToWorld(viewPosition).xz * 0.5 + 0.5) * (1.0 - RAIN_PUDDLES_SIZE * 0.01);

				float puddle  = saturate(FBM(puddleCoords, 3, 1.0) * 0.5 + 0.5);
		  	  	  	  puddle *= pow2(quintic(0.0, 1.0, lightmapCoords.y));
	  				  puddle *= (1.0 - porosity);
			  	  	  puddle *= wetness;
			  	  	  puddle *= quintic(0.89, 0.99, tbn[2].y);
					  puddle  = saturate(puddle);
	
				F0        = clamp(F0 + waterF0 * puddle, 0.0, mix(1.0, 229.5 * rcpMaxVal8, float(F0 * maxVal8 <= 229.5)));
				roughness = mix(roughness, 0.0, puddle);
				normal    = mix(normal, tbn[2], puddle);
			}
		#endif

		/*
		if(blockId == 13) {
        	F0 = 1.0;
        	roughness = EPS;
        	albedoTex.rgb = vec3(1.0);
        	ao = 1.0;
        	emission = 0.0;
        	subsurface = 0.0;
			normal = tbn[2];
    	}
		*/

		vec3 labPbrData0 = vec3(parallaxSelfShadowing, saturate(lightmap));
		vec4 labPbrData1 = vec4(ao, emission, F0, subsurface);
		vec4 labPbrData2 = vec4(albedoTex.rgb, roughness);
		vec2 encNormal   = encodeUnitVector(normalize(normal));
	
		uvec4 shiftedData0  = uvec4(round(labPbrData0 * vec3(1.0, 8191.0, 4095.0)), blockId) << uvec4(0, 1, 14, 26);
		uvec4 shiftedData1  = uvec4(round(labPbrData1 * maxVal8                           )) << uvec4(0, 8, 16, 24);
		uvec4 shiftedData2  = uvec4(round(labPbrData2 * maxVal8                           )) << uvec4(0, 8, 16, 24);
		uvec2 shiftedNormal = uvec2(round(encNormal   * maxVal16                          )) << uvec2(0, 16);

		data0.x = shiftedData0.x  | shiftedData0.y | shiftedData0.z | shiftedData0.w;
		data0.y = shiftedData1.x  | shiftedData1.y | shiftedData1.z | shiftedData1.w;
		data0.z = shiftedData2.x  | shiftedData2.y | shiftedData2.z | shiftedData2.w;
		data0.w = shiftedNormal.x | shiftedNormal.y;

		data1 = encodeUnitVector(normalize(tbn[2]));
	}
#endif
