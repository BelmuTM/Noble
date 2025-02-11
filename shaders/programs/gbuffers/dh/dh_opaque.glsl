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

#if defined STAGE_VERTEX

	flat out int blockId;
	out vec2 lightmapCoords;
	out vec3 vertexNormal;
	out vec3 scenePosition;
	out vec4 vertexColor;

	void main() {
		lightmapCoords = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
		vertexColor    = gl_Color;
		blockId        = dhMaterialId;

		vertexNormal = gl_Normal;

        vec3 cameraOffset   = fract(cameraPosition);
        vec3 vertexPosition = floor(gl_Vertex.xyz + cameraOffset + 0.5) - cameraOffset;

        vec3 viewPosition = transform(gl_ModelViewMatrix, vertexPosition);

		scenePosition = transform(gbufferModelViewInverse, viewPosition);

		gl_Position    = dhProjection * vec4(viewPosition, 1.0);
		gl_Position.xy = gl_Position.xy * RENDER_SCALE + (RENDER_SCALE - 1.0) * gl_Position.w;

		#if TAA == 1
			gl_Position.xy += taaJitter(gl_Position);
		#endif
	}

#elif defined STAGE_FRAGMENT

	/* RENDERTARGETS: 1,3 */

	layout (location = 0) out uvec4 data0;
	layout (location = 1) out vec2  data1;

	flat in int blockId;
	in vec2 lightmapCoords;
	in vec3 vertexNormal;
	in vec3 scenePosition;
	in vec4 vertexColor;

	void main() {
		vec2 fragCoords = gl_FragCoord.xy * texelSize / RENDER_SCALE;
		if(saturate(fragCoords) != fragCoords) discard;

		float fragDistance = length(scenePosition);
    	if(fragDistance < 0.5 * far) { discard; return; }

		vec4 albedoTex = vertexColor;

		#if WHITE_WORLD == 1
	    	albedoTex.rgb = vec3(1.0);
    	#endif

		float roughness = saturate(hardcodedRoughness != 0.0 ? hardcodedRoughness : 1.0);

		float emission = 0.0;

		#if HARDCODED_EMISSION == 1
			if(blockId == DH_BLOCK_ILLUMINATED && emission <= EPS) emission = HARDCODED_EMISSION_VAL;
		#endif

		float subsurface = 0.0;

		#if HARDCODED_SSS == 1
			if(subsurface <= EPS) {
            	if(blockId == DH_BLOCK_LEAVES || blockId == DH_BLOCK_SNOW || blockId == DH_BLOCK_SAND) subsurface = HARDCODED_SSS_VAL;
			}
        #endif

		vec3 labPbrData0 = vec3(1.0, saturate(lightmapCoords));
		vec4 labPbrData1 = vec4(1.0, emission, 0.0, subsurface);
		vec4 labPbrData2 = vec4(albedoTex.rgb, roughness);
		vec2 encNormal   = encodeUnitVector(normalize(vertexNormal));
	
		uvec4 shiftedData0  = uvec4(round(labPbrData0 * labPbrData0Range), blockId) << uvec4(0, 1, 14, 26);
		uvec4 shiftedData1  = uvec4(round(labPbrData1 * maxFloat8                )) << uvec4(0, 8, 16, 24);
		uvec4 shiftedData2  = uvec4(round(labPbrData2 * maxFloat8                )) << uvec4(0, 8, 16, 24);
		uvec2 shiftedNormal = uvec2(round(encNormal   * maxFloat16               )) << uvec2(0, 16);

		data0.x = shiftedData0.x  | shiftedData0.y | shiftedData0.z | shiftedData0.w;
		data0.y = shiftedData1.x  | shiftedData1.y | shiftedData1.z | shiftedData1.w;
		data0.z = shiftedData2.x  | shiftedData2.y | shiftedData2.z | shiftedData2.w;
		data0.w = shiftedNormal.x | shiftedNormal.y;

		data1 = encodeUnitVector(normalize(vertexNormal));
	}

#endif
