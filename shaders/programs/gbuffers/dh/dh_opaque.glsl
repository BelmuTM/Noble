/********************************************************************************/
/*                                                                              */
/*    Noble Shaders                                                             */
/*    Copyright (C) 2026  Belmu                                                 */
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

    flat out uint blockId;
    out vec2 lightmapCoords;
    out vec3 vertexNormal;
    out vec3 scenePosition;
    out vec4 vertexColor;

    void main() {
        lightmapCoords = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
        vertexColor    = gl_Color;
        blockId        = uint(dhMaterialId);

        vertexNormal = gl_Normal;

        vec3 cameraOffset   = fract(cameraPosition);
        vec3 vertexPosition = floor(gl_Vertex.xyz + cameraOffset + 0.5) - cameraOffset;

        vec3 viewPosition = transform(gl_ModelViewMatrix, vertexPosition);

        scenePosition = transform(gbufferModelViewInverse, viewPosition);

        gl_Position    = modProjection * vec4(viewPosition, 1.0);
        gl_Position.xy = gl_Position.xy * RENDER_SCALE + (RENDER_SCALE - 1.0) * gl_Position.w;

        #if TAA == 1
            gl_Position.xy += taaJitter(gl_Position);
        #endif
    }

#elif defined STAGE_FRAGMENT

    /* RENDERTARGETS: 1,3 */

    layout (location = 0) out uvec4 data;
    layout (location = 1) out vec2 geometricNormal;

    flat in uint blockId;
    in vec2 lightmapCoords;
    in vec3 vertexNormal;
    in vec3 scenePosition;
    in vec4 vertexColor;

    void main() {
        #if DOWNSCALED_RENDERING == 1
            vec2 fragCoords = gl_FragCoord.xy * texelSize;
            if (!insideScreenBounds(fragCoords, RENDER_SCALE)) { discard; return; }
        #endif

        float fragDistance = length(scenePosition);
        if (fragDistance < 0.5 * far) { discard; return; }

        vec3 albedo = vertexColor.rgb;

        #if WHITE_WORLD == 1
            albedo = vec3(1.0);
        #endif

        float roughness = saturate(hardcodedRoughness != 0.0 ? hardcodedRoughness : 1.0);

        float emission = 0.0;

        #if HARDCODED_EMISSION == 1
            if (blockId == DH_BLOCK_ILLUMINATED) {
                emission = HARDCODED_EMISSION_VAL;
            }
        #endif

        float subsurface = 0.0;

        #if HARDCODED_SSS == 1
            if (subsurface <= EPS) {
                if (blockId == DH_BLOCK_LEAVES || blockId == DH_BLOCK_SNOW || blockId == DH_BLOCK_SAND) {
                    subsurface = HARDCODED_SSS_VAL;
                }
            }
        #endif

        vec2 encodedNormal = encodeUnitVector(normalize(vertexNormal));

        data = storeMaterial(
            0.0,
            roughness,
            1.0,
            emission,
            subsurface,
            albedo,
            encodedNormal,
            lightmapCoords,
            1.0,
            blockId
        );

        geometricNormal = encodedNormal;
    }

#endif
