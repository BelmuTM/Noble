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

#include "/include/utility/rng.glsl"

#if defined STAGE_VERTEX

    #define attribute in
    attribute vec4 at_tangent;
    attribute vec3 at_midBlock;
    attribute vec3 mc_Entity;
    attribute vec2 mc_midTexCoord;

    flat out int blockId;
    out vec2 textureCoords;
    out vec2 lightmapCoords;

    #if POM > 0 && defined PROGRAM_TERRAIN
        out vec2 texSize;
        out vec2 botLeft;
    #endif

    out vec3 viewPosition;
    out vec3 scenePosition;
    out vec3 midBlock;
    out vec4 vertexColor;
    out mat3 tbn;

    uniform float rcp240;

    #include "/include/vertex/animation.glsl"

    void main() {
        #if (defined PROGRAM_HAND && RENDER_MODE == 1) || (defined PROGRAM_ENTITY && RENDER_MODE == 1 && RENDER_ENTITIES == 0)
            gl_Position = vec4(1.0);
            return;
        #endif

        textureCoords  = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
        lightmapCoords = gl_MultiTexCoord1.xy * rcp240;
        vertexColor    = gl_Color;

        #if defined PROGRAM_ENTITY
            // Thanks Kneemund for the nametag fix (https://github.com/Kneemund)
            if (vertexColor.a >= 0.24 && vertexColor.a < 0.255) {
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
    
        scenePosition = transform(gbufferModelViewInverse, viewPosition);

        #if RENDER_MODE == 0 && defined PROGRAM_TERRAIN && WAVING_PLANTS == 1
            animate(scenePosition, textureCoords.y < mc_midTexCoord.y, getSkylightFalloff(lightmapCoords.y));
        #endif

        midBlock = at_midBlock;
    
        gl_Position    = project(gl_ProjectionMatrix, transform(gbufferModelView, scenePosition));
        gl_Position.xy = gl_Position.xy * RENDER_SCALE + (RENDER_SCALE - 1.0) * gl_Position.w;

        #if TAA == 1
            gl_Position.xy += taaJitter(gl_Position);
        #endif
    }

#elif defined STAGE_FRAGMENT

    /* RENDERTARGETS: 1,3 */

    layout (location = 0) out uvec4 data;
    layout (location = 1) out vec2  geometricNormal;

    flat in int blockId;
    in vec2 textureCoords;
    in vec2 lightmapCoords;

    #if POM > 0 && defined PROGRAM_TERRAIN
        in vec2 texSize;
        in vec2 botLeft;
    #endif

    in vec3 viewPosition;
    in vec3 scenePosition;
    in vec3 midBlock;
    in vec4 vertexColor;
    in mat3 tbn;

    uniform sampler2D gtexture;
    uniform sampler2D normals;
    uniform sampler2D specular;

    #if defined PROGRAM_TERRAIN
        #if POM > 0
            #include "/include/fragment/parallax.glsl"
        #endif

        #if RAIN_PUDDLES == 1
            #include "/include/fragment/puddles.glsl"
        #endif
    #endif

    #if defined PROGRAM_ENTITY
        uniform int entityId;
        uniform vec4 entityColor;
    #endif

    uniform int heldBlockLightValue;
    uniform int heldBlockLightValue2;

    #if DIRECTIONAL_LIGHTMAP == 1 && GI == 0 && !defined PROGRAM_BLOCK && !defined PROGRAM_BEACONBEAM

        vec2 computeLightmap(vec3 scenePosition, vec3 textureNormal) {
            // Thanks ninjamike1211 for the help
            vec2 lightmap = lightmapCoords;

            vec2 blocklightDeriv = vec2(dFdx(lightmap.x), dFdy(lightmap.x));
            vec2 skylightDeriv   = vec2(dFdx(lightmap.y), dFdy(lightmap.y));

            if (lengthSqr(blocklightDeriv) > 1e-10) {
                vec3 lightmapVectorX = normalize(dFdx(scenePosition) * blocklightDeriv.x + dFdy(scenePosition) * blocklightDeriv.y);

                lightmap.x *= saturate(dot(lightmapVectorX, textureNormal) + 0.8) * 0.35 + 0.75;
            } else {
                lightmap.x *= saturate(dot(tbn[2], textureNormal) + 0.8);
            }

            lightmap.y *= saturate(dot(vec3(0.0, 1.0, 0.0), textureNormal) + 0.8) * 0.35 + 0.75;
        
            return any(isnan(lightmap)) || any(lessThan(lightmap, vec2(0.0))) ? lightmapCoords : lightmap;
        }

    #endif

    void main() {
        vec2 fragCoords = gl_FragCoord.xy * texelSize / RENDER_SCALE;
        if (saturate(fragCoords) != fragCoords) { discard; return; }

        #if (defined PROGRAM_HAND && RENDER_MODE == 1) || (defined PROGRAM_ENTITY && RENDER_MODE == 1 && RENDER_ENTITIES == 0)
            discard; return;
        #endif

        vec2 coords = textureCoords;

        float parallaxSelfShadowing = 1.0;

        #if POM > 0 && defined PROGRAM_TERRAIN

            mat2 texDeriv = mat2(dFdx(coords), dFdy(coords));

            #if POM_DEPTH_WRITE == 1
                gl_FragDepth = gl_FragCoord.z;
            #endif

            if (length(scenePosition) < POM_DISTANCE) {
                float height = 1.0, traceDistance = 0.0;
                vec2  shadowCoords = vec2(0.0);

                if (texture(normals, textureCoords).a < 1e-3 || texture(gtexture, textureCoords).a < 0.102) {
                    discard; return;
                }

                coords = parallaxMapping(viewPosition, texDeriv, height, shadowCoords, traceDistance);

                if (saturate(coords) != coords) return;

                #if POM_SHADOWING == 1
                    parallaxSelfShadowing = parallaxShadowing(shadowCoords, height, texDeriv);
                #endif

                #if POM_DEPTH_WRITE == 1
                    gl_FragDepth = projectDepth(unprojectDepth(gl_FragCoord.z) + traceDistance * POM_DEPTH);
                #endif
            }

        #endif

        vec4 albedoTex = texture(gtexture, coords) * vertexColor;
        if (albedoTex.a < 0.102) { discard; return; }

        vec4 normalTex = texture(normals, coords);

        #if !defined PROGRAM_TEXTURED
            vec4 specularTex = texture(specular, coords);
        #else
            vec4 specularTex = vec4(0.0);
        #endif

        vec2 lightmap = lightmapCoords;

        float F0 		 = specularTex.y;
        float ao 		 = normalTex.z;
        float roughness  = saturate(hardcodedRoughness != 0.0 ? hardcodedRoughness : 1.0 - specularTex.x);
        float emission   = specularTex.w * maxFloat8 < 254.5 ? specularTex.w : 0.0;
        float subsurface = saturate(specularTex.z * (maxFloat8 / 190.0) - (65.0 / 190.0));

        #if WHITE_WORLD == 1
            albedoTex.rgb = vec3(1.0);
        #endif

        #if defined PROGRAM_ENTITY
            albedoTex.rgb = mix(albedoTex.rgb, entityColor.rgb, entityColor.a);
            
            ao = all(lessThanEqual(normalTex.rgb, vec3(EPS))) ? 1.0 : ao;
        #endif

        #if defined PROGRAM_BEACONBEAM
            if (albedoTex.a < 0.999) { discard; return; }
            emission   = 1.0;
            lightmap.x = 1.0;
        #endif

        vec3 normal = tbn[2];
        #if !defined PROGRAM_BLOCK && !defined PROGRAM_BEACONBEAM

            if (all(greaterThan(normalTex, vec4(EPS)))) {
                normal.xy = normalTex.xy * 2.0 - 1.0;
                normal.z  = sqrt(1.0 - saturate(dot(normal.xy, normal.xy)));
                normal    = tbn * normal;

                #if DIRECTIONAL_LIGHTMAP == 1 && GI == 0
                    lightmap = computeLightmap(scenePosition, normalize(normal));
                #endif
            }

        #endif

        #if defined PROGRAM_SPIDEREYES
            lightmap = vec2(lightmapCoords.x, 0.0);
        #endif

        #if defined PROGRAM_TERRAIN && RAIN_PUDDLES == 1
            if (wetness > 0.0 && isEyeInWater == 0) {
                float porosity = saturate(specularTex.z * (maxFloat8 / 64.0));
                
                rainPuddles(scenePosition, tbn[2], lightmapCoords, porosity, F0, roughness, normal);
            }
        #endif

        #if HARDCODED_EMISSION == 1
            if (blockId >= LAVA_ID && blockId < SSS_ID && emission <= EPS) emission = HARDCODED_EMISSION_VAL;
        #endif
        
        #if HARDCODED_SSS == 1
            if (blockId > NETHER_PORTAL_ID && blockId <= PLANTS_ID && subsurface <= EPS) subsurface = HARDCODED_SSS_VAL;
        #endif

        float handLight  = min(float(heldBlockLightValue + heldBlockLightValue2), 15.0) / 15.0;
              handLight *= smoothstep(1.0, 0.0, min(HANDLIGHT_DISTANCE * handLight, length(viewPosition)) / (HANDLIGHT_DISTANCE * handLight));

        lightmap.x = max(handLight, lightmap.x);

        int id = blockId;

        #if defined PROGRAM_ENTITY
            // Handling lightning bolts, end crystal and end crystal beams
            if (entityId == 1000) id = LIGHTNING_BOLT_ID;

            if (entityId == 1001 || entityId == 1002) {
                emission = 1.0;
                lightmap = vec2(1.0);
            }
        #endif

        // Flickering fire-powered light sources
        if (id >= FIRE_ID && id <= HANGING_LANTERN_ID) {
            const float speed = 4.0;
            float rng         = FBM(ceil(scenePosition + cameraPosition) + frameTimeCounter * speed * 0.1, 1, 0.5);
            float flickering  = mix(mix(0.8, 0.95, rng), 1.0, (sin(frameTimeCounter * speed * mix(0.3, 0.5, rng)) + 1.0) * 0.5);

            lightmap.x *= flickering;
            emission   *= flickering;
        }

        vec3 labPBRData0 = vec3(parallaxSelfShadowing, saturate(lightmap));
        vec4 labPBRData1 = vec4(ao, emission, F0, subsurface);
        vec4 labPBRData2 = vec4(albedoTex.rgb, roughness);

        vec2 encodedNormal = encodeUnitVector(normalize(normal));
    
        uvec4 shiftedLabPbrData0 = uvec4(round(labPBRData0 * labPBRData0Range), id) << uvec4(0, 1, 14, 26);

        data.x = shiftedLabPbrData0.x | shiftedLabPbrData0.y | shiftedLabPbrData0.z | shiftedLabPbrData0.w;
        data.y = packUnorm4x8(labPBRData1);
        data.z = packUnorm4x8(labPBRData2);
        data.w = packUnorm2x16(encodedNormal);

        geometricNormal = encodeUnitVector(normalize(tbn[2]));
    }

#endif
