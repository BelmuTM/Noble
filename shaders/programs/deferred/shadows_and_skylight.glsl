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

#include "/include/utility/rng.glsl"

#if defined WORLD_OVERWORLD || defined WORLD_END

    #include "/include/atmospherics/atmosphere_header.glsl"

#endif

#if defined STAGE_VERTEX

    out vec2 textureCoords;
    out vec2 vertexCoords;

    #if defined WORLD_OVERWORLD || defined WORLD_END

        flat out vec3    directIlluminance;
        flat out vec3    uniformSkyIlluminance;
        flat out vec3[9] skyIlluminanceCoefficients;

        #include "/include/atmospherics/illuminance_fetch.glsl"

    #endif

    void main() {
        gl_Position    = vec4(gl_Vertex.xy * 2.0 - 1.0, 1.0, 1.0);
        gl_Position.xy = gl_Position.xy * RENDER_SCALE + (RENDER_SCALE - 1.0) * gl_Position.w;
        textureCoords  = gl_Vertex.xy;
        vertexCoords   = gl_Vertex.xy * RENDER_SCALE;

        #if defined WORLD_OVERWORLD || defined WORLD_END

            directIlluminance          = DIRECT_ILLUMINANCE();
            uniformSkyIlluminance      = UNIFORM_SKY_ILLUMINANCE();
            skyIlluminanceCoefficients = SKY_ILLUMINANCE_COEFFICIENTS();

        #endif
    }

#elif defined STAGE_FRAGMENT

    /* RENDERTARGETS: 3,5 */

    layout (location = 0) out vec4 shadowmapOut;
    layout (location = 1) out vec4 illuminanceOut;

    in vec2 textureCoords;
    in vec2 vertexCoords;

    #if defined WORLD_OVERWORLD || defined WORLD_END

        flat in vec3    directIlluminance;
        flat in vec3    uniformSkyIlluminance;
        flat in vec3[9] skyIlluminanceCoefficients;

    #endif

    #if defined WORLD_OVERWORLD && SHADOWS > 0

        #include "/include/fragment/shadows.glsl"

    #endif

    #if defined WORLD_OVERWORLD && CLOUDS_SHADOWS == 1 && CLOUDS_LAYER0_ENABLED == 1

        #include "/include/atmospherics/clouds.glsl"

    #endif

    void main() {
        shadowmapOut   = vec4(1.0, 1.0, 1.0, 0.0);
        illuminanceOut = vec4(0.0);

        #if DOWNSCALED_RENDERING == 1
            vec2 fragCoords = gl_FragCoord.xy * texelSize;
            if (!insideScreenBounds(fragCoords, RENDER_SCALE)) { return; }
        #endif

        float depth = texture(depthtex0, vertexCoords).r;

        bool modFragment = false;

        #if defined CHUNK_LOADER_MOD_ENABLED
        
            if (depth >= 1.0) {
                modFragment = true;
            }

        #endif

        uvec4 dataTexture = texelFetch(GBUFFERS_DATA, ivec2(vertexCoords * viewSize), 0);

        //////////////////////////////////////////////////////////
        /*--------------------- ILLUMINANCE --------------------*/
        //////////////////////////////////////////////////////////

        vec3 skyIlluminance = vec3(0.0);

        #if defined WORLD_OVERWORLD || defined WORLD_END
        
            bool receivesSkylight = true;

            #if defined WORLD_OVERWORLD
                receivesSkylight = unpackLightmap(dataTexture.x).y > EPS;
            #endif

            if (receivesSkylight) {

                #if AO > 0

                    // Directional sky illuminance from bent normals

                    vec3 aoBuffer    = texture(AO_BUFFER, vertexCoords).rgb;
                    vec3 bentNormals = max0(decodeUnitVector(aoBuffer.xy));

                    skyIlluminance = evaluateDirectionalSkyIlluminance(skyIlluminanceCoefficients, bentNormals, aoBuffer.z);

                #else

                    skyIlluminance = vec3(luminance(uniformSkyIlluminance));

                #endif

            }

            if (ivec2(gl_FragCoord.xy) == ivec2(0, 0)) {

                // Direct illuminance
                illuminanceOut.rgb = encodeLog(directIlluminance);

            } else if (ivec2(gl_FragCoord.xy) != ivec2(0, 1)) {

                // Directional sky illuminance
                illuminanceOut.rgb = skyIlluminance;
            }

        #endif
                
        //////////////////////////////////////////////////////////
        /*----------------- SHADOW MAPPING ---------------------*/
        //////////////////////////////////////////////////////////

        if (depth == 1.0) return;
            
        #if defined WORLD_OVERWORLD

            #if SHADOWS > 0

                mat4 projection        = gbufferProjection;
                mat4 projectionInverse = gbufferProjectionInverse;

                #if defined CHUNK_LOADER_MOD_ENABLED

                    if (modFragment) {
                        projection        = modProjection;
                        projectionInverse = modProjectionInverse;
                    }
                    
                #endif

                // Shadowmapping

                vec3 normal = decodeUnitVector(unpackUnorm2x16(dataTexture.w));

                vec3 screenPosition = vec3(textureCoords, depth);
                vec3 viewPosition   = screenToView(screenPosition, projectionInverse, true);
                vec3 scenePosition  = viewToWorld(viewPosition);

                shadowmapOut = calculateShadowMapping(scenePosition, normal, depth);

                // POM self-shadowing

                #if POM > 0 && POM_SHADOWING == 1
                    shadowmapOut.rgb *= unpackParallaxSelfShadowing(dataTexture.x);
                #endif

                // Contact shadows

                #if CONTACT_SHADOWS == 1

                    float contactShadows = 1.0;

                    normal        = mat3(gbufferModelView) * normal;
                    viewPosition += normal * 1e-2;

                    float subsurfaceDepth = 0.0;

                    if (modFragment) {
                        contactShadows = traceContactShadows(modDepthTex0, projection, projectionInverse, viewPosition, RENDER_SCALE, subsurfaceDepth);
                    } else {
                        contactShadows = traceContactShadows(depthtex0, projection, projectionInverse, viewPosition, RENDER_SCALE, subsurfaceDepth);
                    }

                    // Use the subsurface depth from contact shadows if the one from shadow mapping is undefined/invalid
                    #if defined VOXY
                        bool outsideShadowBounds = length(scenePosition) >= shadowDistance - 32;
                    #else
                        bool outsideShadowBounds = length(scenePosition) >= shadowDistance;
                    #endif

                    if (subsurfaceDepth > 0.0 && outsideShadowBounds) {
                        shadowmapOut.a = subsurfaceDepth;
                    }

                    // Apply contact shadows if the shadowmapOut is insufficient (out of bounds or lacks precision)
                    if (shadowmapOut.rgb == vec3(1.0) || luminance(shadowmapOut.rgb) > contactShadows) {
                        shadowmapOut.rgb *= contactShadows;
                    }

                #endif
                
            #endif

            // Clouds shadows

            #if CLOUDS_SHADOWS == 1 && CLOUDS_LAYER0_ENABLED == 1

                illuminanceOut.a = calculateCloudsShadows(getCloudsShadowPosition(gl_FragCoord.xy, atmosphereRayPosition), cloudLayer0, true);

            #endif

        #endif
    }
    
#endif
