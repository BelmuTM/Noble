/***********************************************/
/*          Copyright (C) 2024 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/settings.glsl"
#include "/include/taau_scale.glsl"

#include "/include/common.glsl"

#include "/include/utility/phase.glsl"

#include "/include/atmospherics/constants.glsl"

#if defined WORLD_OVERWORLD || defined WORLD_END
	#include "/include/atmospherics/atmosphere.glsl"
#endif

#if defined STAGE_VERTEX

	flat out int blockId;
	out vec2 lightmapCoords;
    out vec3 vertexNormal;
	out vec3 scenePosition;
	out vec3 directIlluminance;
	out vec4 vertexColor;
    out mat3[2] skyIlluminanceMat;

	void main() {
		lightmapCoords = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
		vertexColor    = gl_Color;
		blockId        = dhMaterialId;

        vertexNormal = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * gl_Normal);
		
        vec3 cameraOffset   = fract(cameraPosition);
        vec3 vertexPosition = floor(gl_Vertex.xyz + cameraOffset + 0.5) - cameraOffset;

        vec3 viewPosition = transform(gl_ModelViewMatrix, vertexPosition);

        scenePosition = transform(gbufferModelViewInverse, viewPosition);

		#if defined WORLD_OVERWORLD || defined WORLD_END
			directIlluminance = texelFetch(ILLUMINANCE_BUFFER, ivec2(0), 0).rgb;
			skyIlluminanceMat = evaluateDirectionalSkyIrradianceApproximation();
		#endif
		
		gl_Position    = transform(gbufferModelView, scenePosition).xyzz * diagonal4(dhProjection) + dhProjection[3];
		gl_Position.xy = gl_Position.xy * RENDER_SCALE + (RENDER_SCALE - 1.0) * gl_Position.w;

		#if TAA == 1 && EIGHT_BITS_FILTER == 0
			gl_Position.xy += taaJitter(gl_Position);
		#endif
	}

#elif defined STAGE_FRAGMENT

	/* RENDERTARGETS: 1,13 */

	layout (location = 0) out uvec4 data;
	layout (location = 1) out vec4 translucents;

	flat in int blockId;
	in vec2 lightmapCoords;
    in vec3 vertexNormal;
	in vec3 scenePosition;
	in vec3 directIlluminance;
	in vec4 vertexColor;
    in mat3[2] skyIlluminanceMat;
	
	#include "/include/fragment/brdf.glsl"

	#if SHADOWS > 0
		#include "/include/fragment/shadowmap.glsl"
	#endif

	#include "/include/fragment/gerstner.glsl"

	void main() {
		vec2 fragCoords = gl_FragCoord.xy * texelSize / RENDER_SCALE;
		if(saturate(fragCoords) != fragCoords) discard;

        float depth       = texelFetch(depthtex0, ivec2(gl_FragCoord.xy), 0).r;
        float linearDepth = linearizeDepth(depth, near, far);

        float linearDepthDh = linearizeDepth(gl_FragCoord.z, dhNearPlane, dhFarPlane);
    
        if(linearDepth < linearDepthDh && depth < 1.0) { discard; return; }

		Material material;
		translucents = vec4(0.0);

		material.lightmap = lightmapCoords;
        material.normal   = vertexNormal;

		// WOTAH
		if(blockId == DH_BLOCK_WATER) {
            material.albedo = vec3(0.0);

			material.F0 = waterF0, material.roughness = 0.0, material.emission = 0.0;

            vec3 tangent = cross(vertexNormal, vec3(1.0));
	        mat3 tbn     = mat3(tangent, cross(tangent, vertexNormal), vertexNormal);

            material.normal = tbn * getWaterNormals(scenePosition + cameraPosition, WATER_OCTAVES);
		} else {
            material.F0 = 0.0;

            material.roughness = saturate(hardcodedRoughness != 0.0 ? hardcodedRoughness : 0.0);

			if(blockId == DH_BLOCK_ILLUMINATED) material.emission = 1.0;

			material.albedo = vertexColor.rgb;

			#if WHITE_WORLD == 1
	    		material.albedo = vec3(1.0);
    		#endif

            #if TONEMAP == ACES
                material.albedo = srgbToAP1Albedo(material.albedo);
            #else
                material.albedo = srgbToLinear(material.albedo);
            #endif

            vec4 shadowmap      = vec4(1.0, 1.0, 1.0, 0.0);
            vec3 skyIlluminance = vec3(0.0);

            #if defined WORLD_OVERWORLD || defined WORLD_END
                #if defined WORLD_OVERWORLD && SHADOWS > 0
                    shadowmap.rgb = abs(calculateShadowMapping(scenePosition, vertexNormal, shadowmap.a));
                #endif

                if(material.lightmap.y > EPS) skyIlluminance = evaluateSkylight(vertexNormal, skyIlluminanceMat);
            #endif

            translucents.rgb = computeDiffuse(scenePosition, shadowLightVector, material, false, shadowmap, directIlluminance, skyIlluminance, 1.0, 1.0);

            translucents.a = vertexColor.a;
		}

		vec3 labPbrData0 = vec3(1.0, saturate(material.lightmap));
		vec4 labPbrData1 = vec4(1.0, material.emission, material.F0, 0.0);
		vec4 labPbrData2 = vec4(vertexColor.rgb, material.roughness);
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
