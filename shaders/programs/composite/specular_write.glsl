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

    out vec2 textureCoords;
    out vec2 vertexCoords;

    flat out vec3 directIlluminance;
    flat out vec3 skyIlluminance;

    #include "/include/atmospherics/illuminance_fetch.glsl"

    void main() {
        gl_Position    = vec4(gl_Vertex.xy * 2.0 - 1.0, 1.0, 1.0);
        gl_Position.xy = gl_Position.xy * RENDER_SCALE + (RENDER_SCALE - 1.0) * gl_Position.w; + (RENDER_SCALE - 1.0);
        textureCoords  = gl_Vertex.xy;
        vertexCoords   = gl_Vertex.xy * RENDER_SCALE;

        #if defined WORLD_OVERWORLD || defined WORLD_END

            directIlluminance = DIRECT_ILLUMINANCE();
            skyIlluminance    = UNIFORM_SKY_ILLUMINANCE();

        #endif
    }

#elif defined STAGE_FRAGMENT

    /* RENDERTARGETS: 0 */

    layout (location = 0) out vec3 lightingOut;

    in vec2 textureCoords;
    in vec2 vertexCoords;

    flat in vec3 directIlluminance;
    flat in vec3 skyIlluminance;

    #include "/include/utility/rng.glsl"

    #include "/include/atmospherics/constants.glsl"

    #include "/include/utility/phase.glsl"
    #include "/include/utility/sampling.glsl"

    #include "/include/material/brdf.glsl"
    
    #include "/include/fragment/raytracer.glsl"
    #include "/include/fragment/shadows.glsl"

    #include "/include/atmospherics/fog.glsl"

    #if REFRACTIONS > 0
        #include "/include/fragment/refractions.glsl"
    #endif

    #include "/include/post/exposure.glsl"

    void main() {
        
        lightingOut = vec3(0.0);

        #if DOWNSCALED_RENDERING == 1
            vec2 fragCoords = gl_FragCoord.xy * texelSize;
            if (!insideScreenBounds(fragCoords, RENDER_SCALE)) { return; }
        #endif

        // Specular setup

        bool modFragment = false;

        float depth0 = texture(depthtex0, vertexCoords).r;
        float depth1 = texture(depthtex1, vertexCoords).r;

        vec3 screenPosition = vec3(vertexCoords, depth1);

        mat4 projection        = gbufferProjection;
        mat4 projectionInverse = gbufferProjectionInverse;

        float nearPlane = near;
        float farPlane  = far;

        #if defined CHUNK_LOADER_MOD_ENABLED

            if (depth1 >= 1.0) {
                modFragment = true;

                #if defined VOXY
                    depth0 = texture(modDepthTex0, textureCoords).r;
                    depth1 = texture(modDepthTex1, textureCoords).r;
                #else
                    depth0 = texture(modDepthTex0, vertexCoords).r;
                    depth1 = texture(modDepthTex1, vertexCoords).r;
                #endif
                        
                projection        = modProjection;
                projectionInverse = modProjectionInverse;
            
                nearPlane = modNearPlane;
                farPlane  = modFarPlane;
            }
            
        #endif

        vec3 viewPosition0 = screenToView(vec3(textureCoords, depth0), projectionInverse, true);

        vec3 scenePosition0 = viewToWorld(viewPosition0);

        // Specular lighting

        float exposure = CURRENT_EXPOSURE();

        lightingOut = texture(MAIN_BUFFER, vertexCoords).rgb / exposure;

        float skylight = 1.0;

        if (depth0 < 1.0) {

            // Terrain fragments (refractions + specular)

            bool isOpaque = abs(depth0 - depth1) < 1e-6;

            Material material = getMaterial(vertexCoords);

            skylight = getSkylightFalloff(material.lightmap.y);

            // Metals
            if (material.F0 * maxFloat8 > labPBRMetals) {
                lightingOut = vec3(0.0);
            }

            //////////////////////////////////////////////////////////
            /*-------------------- REFRACTIONS ---------------------*/
            //////////////////////////////////////////////////////////

            #if REFRACTIONS > 0
            
                if (!isOpaque && material.F0 > EPS) {

                    vec3 viewPosition1 = screenToView(vec3(textureCoords, depth1), projectionInverse, true);

                    lightingOut = computeRefractions(
                        modFragment,
                        projection,
                        projectionInverse,
                        viewPosition0,
                        viewPosition1,
                        material.albedo,
                        material.normal,
                        material.emission,
                        material.N,
                        material.id,
                        exposure,
                        screenPosition
                    );

                }

            #endif

            //////////////////////////////////////////////////////////
            /*-------------------- REFLECTIONS ---------------------*/
            //////////////////////////////////////////////////////////

            vec3 directSpecular      = vec3(0.0);
            vec3 environmentSpecular = vec3(0.0);

            #if SPECULAR == 1

                // Specular visibility computation

                vec3 visibility = vec3(1.0);

                vec3 directIlluminanceSpecular = directIlluminance;

                #if defined WORLD_OVERWORLD || defined WORLD_END

                    #if defined WORLD_OVERWORLD

                        #if SHADOWS > 0

                            if (!modFragment) {

                                if (isOpaque) {
                                    visibility = texture(SHADOWMAP_BUFFER, max(screenPosition.xy, texelSize)).rgb;

                                } else {
                                    vec3 shadowPosition = worldToShadowScreen(scenePosition0) - vec3(0.0, 0.0, 1e-3);
                                    // Fragments outside of shadow bounds are considered unoccluded
                                    visibility = insideScreenBounds(shadowPosition, 1.0) ? vec3(shadowVisibility(shadowtex0, shadowPosition)) : vec3(1.0);
                                }

                            }

                        #endif

                        #if CLOUDS_SHADOWS == 1 && CLOUDS_LAYER0_ENABLED == 1

                            visibility *= getCloudsShadows(scenePosition0);

                        #endif

                    #endif
        
                    #if defined SUNLIGHT_LEAKING_FIX

                        directIlluminanceSpecular *= float(material.lightmap.y > EPS || isEyeInWater == 1);

                    #endif

                #endif

                // Direct (sun/moon) specular

                if (maxOf(visibility) > EPS && material.F0 > EPS) {

                    directSpecular = computeSpecular(
                        -normalize(viewPosition0),
                        shadowLightVector,
                        material.normal,
                        material.N,
                        material.K,
                        material.alpha
                    ) * directIlluminanceSpecular;

                }

            #endif

            // Fetching environment reflections

            #if REFLECTIONS > 0
            
                environmentSpecular = texture(REFLECTIONS_BUFFER, vertexCoords).rgb;

            #endif

            // Applying direct and environment specular

            lightingOut += directSpecular;
            lightingOut += environmentSpecular;
        }

        //////////////////////////////////////////////////////////
        /*------------------ EYE TO FRONT FOG ------------------*/
        //////////////////////////////////////////////////////////

        vec3 scatteringFront    = vec3(0.0);
        vec3 transmittanceFront = vec3(1.0);

        #if defined WORLD_OVERWORLD || defined WORLD_END

            vec3 directIlluminanceFinal = directIlluminance;

            vec3 tmp = normalize(scenePosition0 - gbufferModelViewInverse[3].xyz);

            #if defined WORLD_OVERWORLD
                float VdotL = dot(tmp, shadowLightVectorWorld);
            #elif defined WORLD_END
                float VdotL = dot(tmp, starVector);
            #endif

        #else

            vec3 directIlluminanceFinal = getBlockLightColor();
            
            float VdotL = 0.0;
            
        #endif

        bool sky = depth0 == 1.0;

        if (isEyeInWater == 1) {

            #if defined WORLD_OVERWORLD || defined WORLD_END

                #if WATER_FOG == 0
                    computeWaterFogApproximation(scatteringFront, transmittanceFront, gbufferModelViewInverse[3].xyz, scenePosition0, VdotL, directIlluminanceFinal, skyIlluminance, skylight);
                #else
                    computeVolumetricWaterFog(scatteringFront, transmittanceFront, gbufferModelViewInverse[3].xyz, scenePosition0, VdotL, directIlluminanceFinal, skyIlluminance, skylight, sky);
                #endif

            #endif

        } else {

            #if AIR_FOG == 1
                computeVolumetricAirFog(scatteringFront, transmittanceFront, gbufferModelViewInverse[3].xyz, scenePosition0, viewPosition0, farPlane, VdotL, directIlluminanceFinal, skyIlluminance, sky);
            #elif AIR_FOG == 2
                computeAirFogApproximation(scatteringFront, transmittanceFront, viewPosition0, farPlane, VdotL, directIlluminanceFinal, skyIlluminance, skylight);
            #endif

        }
        
        // Applying front fog

        lightingOut = lightingOut * transmittanceFront + scatteringFront;

        lightingOut *= exposure;
    }

#endif
