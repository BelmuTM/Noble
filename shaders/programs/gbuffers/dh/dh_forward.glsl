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

#include "/include/utility/phase.glsl"

#include "/include/atmospherics/constants.glsl"

#if defined WORLD_OVERWORLD || defined WORLD_END
    #include "/include/atmospherics/atmosphere.glsl"
#endif

#if defined STAGE_VERTEX

    flat out uint blockId;
    out vec2 lightmapCoords;
    out vec3 vertexNormal;
    out vec3 scenePosition;
    out vec4 vertexColor;
    out vec3 directIlluminance;
    out mat3[2] skyIlluminanceMat;

    void main() {
        lightmapCoords = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
        vertexColor    = gl_Color;
        blockId        = uint(dhMaterialId);

        vertexNormal = gl_Normal;
        
        vec3 cameraOffset   = fract(cameraPosition);
        vec3 vertexPosition = floor(gl_Vertex.xyz + cameraOffset + 0.5) - cameraOffset;

        vec3 viewPosition = transform(gl_ModelViewMatrix, vertexPosition);

        scenePosition = transform(gbufferModelViewInverse, viewPosition);

        #if defined WORLD_OVERWORLD || defined WORLD_END
            directIlluminance = texelFetch(IRRADIANCE_BUFFER, ivec2(0), 0).rgb;
            skyIlluminanceMat = evaluateDirectionalSkyIrradianceApproximation();
        #endif
        
        gl_Position    = modProjection * vec4(viewPosition, 1.0);
        gl_Position.xy = gl_Position.xy * RENDER_SCALE + (RENDER_SCALE - 1.0) * gl_Position.w;

        #if TAA == 1
            gl_Position.xy += taaJitter(gl_Position);
        #endif
    }

#elif defined STAGE_FRAGMENT

    /* RENDERTARGETS: 1,0 */

    layout (location = 0) out uvec4 data;
    layout (location = 1) out vec4 translucents;

    flat in uint blockId;
    in vec2 lightmapCoords;
    in vec3 vertexNormal;
    in vec3 scenePosition;
    in vec4 vertexColor;
    in vec3 directIlluminance;
    in mat3[2] skyIlluminanceMat;

    #include "/include/utility/rng.glsl"
    
    #include "/include/fragment/brdf.glsl"

    #if SHADOWS > 0
        #include "/include/fragment/shadows.glsl"
    #endif

    #include "/include/fragment/gerstner.glsl"

    void main() {
        translucents = vec4(0.0);

        #if DOWNSCALED_RENDERING == 1
            vec2 fragCoords = gl_FragCoord.xy * texelSize;
            if (!insideScreenBounds(fragCoords, RENDER_SCALE)) { discard; return; }
        #endif

        float depth       = texelFetch(depthtex0, ivec2(gl_FragCoord.xy), 0).r;
        float linearDepth = linearizeDepth(depth, near, far);

        float linearDepthDh = linearizeDepth(gl_FragCoord.z, dhNearPlane, dhFarPlane);
    
        if (linearDepth < linearDepthDh && depth < 1.0) { discard; return; }

        vec3 albedo = vertexColor.rgb;

        Material material;

        material.lightmap = lightmapCoords;
        material.normal   = vertexNormal;

        material.ao         = 1.0;
        material.subsurface = 0.0;

        // WOTAH
        if (blockId == DH_BLOCK_WATER) {
            material.F0        = waterF0;
            material.roughness = 0.0;
            material.emission  = 0.0;
            albedo             = vec3(0.0);

            const mat3 tbn = mat3(
                vec3(1.0, 0.0, 0.0),
                vec3(0.0, 0.0, 1.0),
                vec3(0.0, 1.0, 0.0)
            );

            material.normal = tbn * getWaterNormal(scenePosition + cameraPosition, WATER_OCTAVES);
        } else {
            material.F0 = 0.0;

            material.roughness = saturate(hardcodedRoughness != 0.0 ? hardcodedRoughness : 0.0);

            if (blockId == DH_BLOCK_ILLUMINATED) {
                material.emission = 1.0;
            }

            #if WHITE_WORLD == 1
                material.albedo = vec3(1.0);
            #endif

            #if TONEMAP == ACES
                material.albedo = srgbToAP1Albedo(albedo);
            #else
                material.albedo = srgbToLinear(albedo);
            #endif

            material.N = vec3(f0ToIOR(material.F0));
            material.K = vec3(0.0);

            vec4 shadowmap      = vec4(1.0, 1.0, 1.0, 0.0);
            vec3 skyIlluminance = vec3(0.0);

            #if defined WORLD_OVERWORLD || defined WORLD_END
                #if defined WORLD_OVERWORLD && SHADOWS > 0
                    shadowmap.rgb = abs(calculateShadowMapping(scenePosition, vertexNormal, gl_FragDepth, shadowmap.a));
                #endif

                if (material.lightmap.y > EPS) {
                    skyIlluminance = evaluateSkylight(vertexNormal, skyIlluminanceMat);
                }
            #endif

            translucents.rgb = computeDiffuse(scenePosition, shadowLightVectorWorld, material, false, shadowmap, directIlluminance, skyIlluminance, 1.0, 1.0);

            translucents.rgb = max0(log2(translucents.rgb + 1.0));

            translucents.a = vertexColor.a;
        }
        
        vec2 encodedNormal = encodeUnitVector(normalize(material.normal));

        data = storeMaterial(
            material.F0,
            material.roughness,
            material.ao,
            material.emission,
            material.subsurface,
            albedo,
            encodedNormal,
            material.lightmap,
            1.0,
            blockId
        );
    }

#endif
