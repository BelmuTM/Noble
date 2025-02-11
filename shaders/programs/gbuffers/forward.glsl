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
#include "/include/taau_scale.glsl"

#include "/include/common.glsl"

#include "/include/utility/phase.glsl"

#include "/include/atmospherics/constants.glsl"

#if defined WORLD_OVERWORLD || defined WORLD_END
	#include "/include/atmospherics/atmosphere.glsl"
#endif

#if defined STAGE_VERTEX

	#define attribute in
	attribute vec4 at_tangent;
	attribute vec3 at_midBlock;
	attribute vec3 mc_Entity;

	flat out int blockId;
	out vec2 textureCoords;
	out vec2 lightmapCoords;
	out vec3 scenePosition;
	out vec3 directIlluminance;
	out vec4 vertexColor;
	out mat3[2] skyIlluminanceMat;
	out mat3 tbn;

	uniform float rcp240;

	void main() {
		#if defined PROGRAM_HAND && DISCARD_HAND == 1
			gl_Position = vec4(1.0);
			return;
		#endif

		textureCoords  = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
		lightmapCoords = gl_MultiTexCoord1.xy * rcp240;
		vertexColor    = gl_Color;
		
    	vec3 viewPosition = (gl_ModelViewMatrix * gl_Vertex).xyz;

    	tbn[2] = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * gl_Normal);
    	tbn[0] = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * at_tangent.xyz);
		tbn[1] = cross(tbn[0], tbn[2]) * sign(at_tangent.w);

		blockId = int((mc_Entity.x - 1000.0) + 0.25);

		#if defined WORLD_OVERWORLD || defined WORLD_END
			directIlluminance = texelFetch(ILLUMINANCE_BUFFER, ivec2(0), 0).rgb;
			skyIlluminanceMat = evaluateDirectionalSkyIrradianceApproximation();
		#endif

		scenePosition = transform(gbufferModelViewInverse, viewPosition);
		
		gl_Position    = project(gl_ProjectionMatrix, transform(gbufferModelView, scenePosition));
		gl_Position.xy = gl_Position.xy * RENDER_SCALE + (RENDER_SCALE - 1.0) * gl_Position.w;

		#if TAA == 1
			gl_Position.xy += taaJitter(gl_Position);
		#endif
	}

#elif defined STAGE_FRAGMENT

	/* RENDERTARGETS: 1,13 */

	layout (location = 0) out uvec4 data;
	layout (location = 1) out vec4 translucents;

	flat in int blockId;
	in vec2 textureCoords;
	in vec2 lightmapCoords;
	in vec3 scenePosition;
	in vec3 directIlluminance;
	in vec4 vertexColor;
	in mat3[2] skyIlluminanceMat;
	in mat3 tbn;
	
	#include "/include/fragment/brdf.glsl"

	#if SHADOWS > 0
		#include "/include/fragment/shadows.glsl"
	#endif

	#include "/include/fragment/gerstner.glsl"

	void main() {
		vec2 fragCoords = gl_FragCoord.xy * texelSize / RENDER_SCALE;
		if(saturate(fragCoords) != fragCoords) discard;

		#if defined PROGRAM_HAND && DISCARD_HAND == 1
			discard;
		#endif

		vec4 albedoTex = texture(tex, textureCoords);
		if(albedoTex.a < 0.102) discard;

		vec4 normalTex   = vec4(0.0);
		vec4 specularTex = vec4(0.0);

		#if !defined PROGRAM_TEXTURED && !defined PROGRAM_TEXTURED_LIT
			normalTex   = texture(normals,  textureCoords);
			specularTex = texture(specular, textureCoords);
		#endif

		albedoTex *= vertexColor;

		Material material;
		translucents = vec4(0.0);

		material.lightmap = lightmapCoords;

		vec4 shadowmap = vec4(1.0, 1.0, 1.0, 0.0);

		#if defined WORLD_OVERWORLD && SHADOWS > 0
			shadowmap.rgb = abs(calculateShadowMapping(scenePosition, tbn[2], gl_FragDepth, shadowmap.a));
		#endif

		// WOTAH
		if(blockId == WATER_ID) { 
			material.F0 = waterF0, material.roughness = 0.0, material.ao = 1.0, material.emission = 0.0, material.subsurface = 0.0;

			vec3 scenePositionWater = scenePosition + cameraPosition;

			#if WATER_PARALLAX == 1
				if(length(scenePosition) < WATER_PARALLAX_DISTANCE) {
					vec3 tangentDirection = normalize(scenePosition) * tbn;
					scenePositionWater.xz = parallaxMappingWater(scenePositionWater.xz, tangentDirection, WATER_OCTAVES);
				}
			#endif

    		material.albedo = shadowmap.rgb;
			material.normal = tbn * getWaterNormals(scenePositionWater, WATER_OCTAVES);
		
		} else {
			#if defined PROGRAM_TEXTURED || defined PROGRAM_TEXTURED_LIT
				material.F0         = 0.0;
    			material.roughness  = 1.0;
    			material.ao         = 1.0;
				material.emission   = 0.0;
    			material.subsurface = 0.0;
			#else
				material.F0         = specularTex.y;
    			material.roughness  = saturate(hardcodedRoughness != 0.0 ? hardcodedRoughness : 1.0 - specularTex.x);
    			material.ao         = normalTex.z;
				material.emission   = specularTex.w * maxFloat8 < 254.5 ? specularTex.w : 0.0;
    			material.subsurface = saturate(specularTex.z * (maxFloat8 / 190.0) - (65.0 / 190.0));
			#endif

			if(blockId == NETHER_PORTAL_ID) material.emission = 1.0;

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

			#if REFRACTIONS == 0
				bool shadeTranslucents = true;
			#else
				bool shadeTranslucents = material.F0 <= EPS;
			#endif

			if(material.F0 * maxFloat8 <= 229.5 && shadeTranslucents) {
    			#if TONEMAP == ACES
        			material.albedo = srgbToAP1Albedo(material.albedo);
    			#else
        			material.albedo = srgbToLinear(material.albedo);
    			#endif

        		material.N = vec3(f0ToIOR(material.F0));
        		material.K = vec3(0.0);

				vec3 skyIlluminance = vec3(0.0);

				#if defined WORLD_OVERWORLD || defined WORLD_END
					if(material.lightmap.y > EPS) skyIlluminance = evaluateSkylight(material.normal, skyIlluminanceMat);
				#endif

				#if !defined PROGRAM_TEXTURED && !defined PROGRAM_TEXTURED_LIT && !defined PROGRAM_SPIDEREYES
					bool isMetal = material.F0 * maxFloat8 > 229.5;

					translucents.rgb = computeDiffuse(scenePosition, shadowLightVector, material, isMetal, shadowmap, directIlluminance, skyIlluminance, 1.0, 1.0);
				#else
					vec3 diffuse = vec3(RCP_PI);

					diffuse *= directIlluminance * shadowmap.rgb;

					vec3 skylight = skyIlluminance;

					#if defined WORLD_OVERWORLD
						skylight *= getSkylightFalloff(material.lightmap.y);
					#endif

					vec3 blocklightColor = getBlockLightColor(material);
					vec3 blocklight      = blocklightColor * getBlocklightFalloff(material.lightmap.x);
					vec3 emissiveness    = material.emission * blocklightColor;

					#if defined WORLD_OVERWORLD || defined WORLD_END
						const vec3 ambient = vec3(0.2);
					#else
						const vec3 ambient = vec3(1.0);
					#endif

					diffuse += blocklight + skylight + ambient;
					diffuse += emissiveness;

					translucents.rgb = material.albedo * diffuse;
				#endif

				translucents.a = albedoTex.a;
			}
		}

		vec3 labPbrData0 = vec3(1.0, saturate(material.lightmap));
		vec4 labPbrData1 = vec4(material.ao, material.emission, material.F0, material.subsurface);
		vec4 labPbrData2 = vec4(material.albedo, material.roughness);
		vec2 encNormal   = encodeUnitVector(normalize(material.normal));
	
		uvec4 shiftedData0  = uvec4(round(labPbrData0 * labPbrData0Range), blockId) << uvec4(0, 1, 14, 26);
		uvec4 shiftedData1  = uvec4(round(labPbrData1 * maxFloat8                )) << uvec4(0, 8, 16, 24);
		uvec4 shiftedData2  = uvec4(round(labPbrData2 * maxFloat8                )) << uvec4(0, 8, 16, 24);
		uvec2 shiftedNormal = uvec2(round(encNormal   * maxFloat16               )) << uvec2(0, 16);

		data.x = shiftedData0.x  | shiftedData0.y | shiftedData0.z | shiftedData0.w;
		data.y = shiftedData1.x  | shiftedData1.y | shiftedData1.z | shiftedData1.w;
		data.z = shiftedData2.x  | shiftedData2.y | shiftedData2.z | shiftedData2.w;
		data.w = shiftedNormal.x | shiftedNormal.y;
	}
	
#endif
