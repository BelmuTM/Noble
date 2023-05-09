/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/include/common.glsl"
#include "/include/atmospherics/atmosphere.glsl"

#if defined STAGE_VERTEX

	#define attribute in
	attribute vec4 at_tangent;
	attribute vec3 mc_Entity;

	flat out int blockId;
	out vec2 textureCoords;
	out vec2 lightmapCoords;
	out vec3 viewPosition;
	out vec3 directIlluminance;
	out mat3[2] skyIlluminanceMat;
	out vec4 vertexColor;
	out mat3 tbn;

	void main() {
		#if defined PROGRAM_HAND && DISCARD_HAND == 1
			gl_Position = vec4(1.0);
			return;
		#endif

		textureCoords  = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
		lightmapCoords = gl_MultiTexCoord1.xy * rcp(240.0);
		vertexColor    = gl_Color;
		
    	viewPosition = transform(gl_ModelViewMatrix, gl_Vertex.xyz);

    	tbn[2] = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * gl_Normal);
    	tbn[0] = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * at_tangent.xyz);
		tbn[1] = cross(tbn[0], tbn[2]) * sign(at_tangent.w);

		blockId 	= int((mc_Entity.x - 1000.0) + 0.25);
		gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;

		directIlluminance = texelFetch(ILLUMINANCE_BUFFER, ivec2(0), 0).rgb;
		skyIlluminanceMat = evaluateDirectionalSkyIrradianceApproximation();

		#if TAA == 1
			gl_Position.xy += taaJitter(gl_Position);
    	#endif
	}

#elif defined STAGE_FRAGMENT

	/* RENDERTARGETS: 1,4 */

	layout (location = 0) out uvec4 data;
	layout (location = 1) out vec4 translucents;

	flat in int blockId;
	in vec2 textureCoords;
	in vec2 lightmapCoords;
	in vec3 viewPosition;
	in vec3 directIlluminance;
	in mat3[2] skyIlluminanceMat;
	in vec4 vertexColor;
	in mat3 tbn;

	#include "/include/fragment/brdf.glsl"

	#if SHADOWS == 1
		#include "/include/fragment/shadows.glsl"
	#endif

	void main() {
		#if defined PROGRAM_HAND && DISCARD_HAND == 1
			discard;
		#endif

		vec4 albedoTex = texture(tex, textureCoords);
		if(albedoTex.a < 0.102) discard;

		vec4 normalTex   = vec4(0.0);
		vec4 specularTex = vec4(0.0);

		#if !defined PROGRAM_TEXTURED
			normalTex   = texture(normals,  textureCoords);
			specularTex = texture(specular, textureCoords);
		#endif

		albedoTex *= vertexColor;

		Material material;
		translucents = vec4(0.0);

		// WOTAH
		if(blockId == 1) { 
			material.F0 = waterF0, material.roughness = 0.0, material.ao = 1.0, material.emission = 0.0, material.subsurface = 0.0;

    		material.albedo = vec3(0.0);
			material.normal = tbn * getWaterNormals(viewToWorld(viewPosition), WATER_OCTAVES);
		
		} else {
			material.lightmap = lightmapCoords;

			#if defined PROGRAM_TEXTURED || defined PROGRAM_TEXTURED_LIT
				material.F0         = 0.0;
    			material.roughness  = 1.0;
    			material.ao         = 1.0;
				material.emission   = 0.0;
    			material.subsurface = 0.0;

				#if defined PROGRAM_TEXTURED_LIT
					material.lightmap = vec2(material.lightmap.x, 0.0);
				#endif
			#else
				material.F0         = specularTex.y;
    			material.roughness  = saturate(hardCodedRoughness != 0.0 ? hardCodedRoughness : 1.0 - specularTex.x);
    			material.ao         = normalTex.z;
				material.emission   = specularTex.w * maxVal8 < 254.5 ? specularTex.w : 0.0;
    			material.subsurface = (specularTex.z * maxVal8) < 65.0 ? 0.0 : specularTex.z;
			#endif

			material.albedo = albedoTex.rgb;

			#if WHITE_WORLD == 1
	    		material.albedo = vec3(1.0);
    		#endif

			material.normal = tbn[2];
			if(all(greaterThan(normalTex, vec4(EPS)))) {
				material.normal.xy = normalTex.xy * 2.0 - 1.0;
				material.normal.z  = sqrt(1.0 - saturate(dot(material.normal.xy, material.normal.xy)));
				material.normal    = tbn * material.normal;
			}

			#if GI == 0
				#if REFRACTIONS == 0
					bool shadeTranslucents = true;
				#else
					bool shadeTranslucents = material.F0 < EPS;
				#endif

				if(material.F0 * maxVal8 <= 229.5 && shadeTranslucents) {
					vec3 scenePosition = viewToScene(viewPosition);

					#if TONEMAP == ACES
       					material.albedo = srgbToAP1Albedo(material.albedo);
    				#endif

					if(material.F0 * maxVal8 > 229.5) {
        				mat2x3 hcm = getHardcodedMetal(material);
        				material.N = hcm[0], material.K = hcm[1];
    				} else {
        				material.N = vec3(f0ToIOR(material.F0));
        				material.K = vec3(0.0);
    				}

					vec4 shadowmap      = vec4(1.0, 1.0, 1.0, 0.0);
					vec3 skyIlluminance = vec3(0.0);

					#if defined WORLD_OVERWORLD
						#if SHADOWS == 1
							shadowmap.rgb = abs(calculateShadowMapping(scenePosition, tbn[2], shadowmap.a));
						#endif

						if(material.lightmap.y > EPS) skyIlluminance = evaluateSkylight(material.normal, skyIlluminanceMat);
					#endif

					vec3 directIlluminanceTmp = directIlluminance;

					float isSkyOccluded = float(getSkylightFalloff(material.lightmap.y) > EPS || isEyeInWater == 1);
    				#if defined SUNLIGHT_LEAKING_FIX
        				directIlluminanceTmp *= isSkyOccluded;
        				skyIlluminance       *= isSkyOccluded;
    				#endif

					translucents.rgb = computeDiffuse(scenePosition, shadowLightVector, material, shadowmap, directIlluminanceTmp, skyIlluminance, 1.0, 1.0);
					translucents.a   = albedoTex.a;
				}
			#endif
		}

		vec3 labPbrData0 = vec3(0.0, lightmapCoords);
		vec4 labPbrData1 = vec4(material.ao, material.emission, material.F0, material.subsurface);
		vec4 labPbrData2 = vec4(material.albedo, material.roughness);
		vec2 encNormal   = encodeUnitVector(normalize(material.normal));
	
		uvec4 shiftedData0  = uvec4(round(labPbrData0 * vec3(1.0, 8191.0, 4095.0)), blockId) << uvec4(0, 1, 14, 26);
		uvec4 shiftedData1  = uvec4(round(labPbrData1 * maxVal8))                            << uvec4(0, 8, 16, 24);
		uvec4 shiftedData2  = uvec4(round(labPbrData2 * maxVal8))							 << uvec4(0, 8, 16, 24);
		uvec2 shiftedNormal = uvec2(round(encNormal   * maxVal16))                           << uvec2(0, 16);

		data.x = shiftedData0.x  | shiftedData0.y | shiftedData0.z | shiftedData0.w;
		data.y = shiftedData1.x  | shiftedData1.y | shiftedData1.z | shiftedData1.w;
		data.z = shiftedData2.x  | shiftedData2.y | shiftedData2.z | shiftedData2.w;
		data.w = shiftedNormal.x | shiftedNormal.y;
	}
#endif
