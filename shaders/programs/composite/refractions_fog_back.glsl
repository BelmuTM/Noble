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

        #if defined OVERWORLD_OR_END

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

    #include "/include/atmospherics/atmosphere_header.glsl"

    #include "/include/fragment/shadows.glsl"
    
    #include "/include/atmospherics/fog.glsl"

    #if REFRACTIONS > 0

        #include "/include/material/brdf.glsl"
        #include "/include/fragment/raytracer.glsl"
        #include "/include/fragment/refractions.glsl"

    #endif

    #include "/include/post/exposure.glsl"

    void main() {
        
        lightingOut = vec3(0.0);

        #if DOWNSCALED_RENDERING == 1
            vec2 fragCoords = gl_FragCoord.xy * texelSize;
            if (!insideScreenBounds(fragCoords, RENDER_SCALE)) { return; }
        #endif

        // Inverting pre-exposure to retrieve range

        float exposure    = CURRENT_EXPOSURE();
        float invExposure = 1.0 / exposure;

        vec4 alphaBlendedLighting = texture(MAIN_BUFFER, vertexCoords);

        lightingOut.rgb = alphaBlendedLighting.rgb * invExposure;

        // Fog setup

        float depth0 = texture(depthBuffer0, vertexCoords).r;

        if (depth0 >= 1.0) {
            lightingOut *= exposure;
            return;
        }

        float depth1 = texture(depthBuffer1, vertexCoords).r;

        vec3 screenPosition0 = vec3(textureCoords, depth0);
        vec3 screenPosition1 = vec3(textureCoords, depth1);

        vec3 viewPosition0 = screenToView(screenPosition0, projectionInverseMatrix, true);
        vec3 viewPosition1 = screenToView(screenPosition1, projectionInverseMatrix, true);

        vec3 scatteringBack    = vec3(0.0);
        vec3 transmittanceBack = vec3(1.0);

        if (viewPosition0.z != viewPosition1.z) {

            Material material = getMaterial(vertexCoords);

            //////////////////////////////////////////////////////////
            /*-------------------- REFRACTIONS ---------------------*/
            //////////////////////////////////////////////////////////

            #if REFRACTIONS > 0
            
                if (material.F0 > minRefractionsF0) {

                    lightingOut.rgb = computeRefractions(
                        screenPosition0,
                        viewPosition0,
                        viewPosition1,
                        material.albedo,
                        material.normal,
                        material.emission,
                        material.N,
                        material.id,
                        invExposure,
                        screenPosition1
                    );

                }

            #endif

            //////////////////////////////////////////////////////////
            /*---------------- FRONT TO BACK FOG -------------------*/
            //////////////////////////////////////////////////////////

            bool skyTranslucents = screenPosition1.z >= 1.0;

            float skyLight = getSkylightFalloff(material.lightmap.y);

            vec3 scenePosition0 = viewToWorld(viewPosition0);
            vec3 scenePosition1 = viewToWorld(screenToView(screenPosition1, projectionInverseMatrix, true));
        
            #if defined OVERWORLD_OR_END

                vec3 directIlluminanceFinal = directIlluminance;

                float VdotL = dot(normalize(scenePosition0 - gbufferModelViewInverse[3].xyz), lightVectorWorld);

            #else

                vec3 directIlluminanceFinal = blockLightValue;
                
                float VdotL = 0.0;
                
            #endif

            if (isEyeInWater == 0 && isWater(material.id)) {

                // Water fog

                #if defined OVERWORLD_OR_END

                    #if WATER_FOG == 0

                        // Raymarched

                        computeVolumetricWaterFog(
                            scatteringBack, transmittanceBack,
                            scenePosition0, scenePosition1,
                            VdotL,
                            directIlluminanceFinal, skyIlluminance,
                            skyLight
                        );
                    
                    #else

                        // Approximation

                        computeWaterFogApproximation(
                            scatteringBack, transmittanceBack,
                            scenePosition0, scenePosition1,
                            VdotL,
                            directIlluminanceFinal, skyIlluminance,
                            skyLight
                        ); 
                    
                    #endif

                #endif

            } else {

                // Air fog

                #if AIR_FOG == 1

                    // Raymarched

                    computeVolumetricAirFog(
                        scatteringBack, transmittanceBack,
                        scenePosition0, scenePosition1,
                        VdotL,
                        directIlluminanceFinal, skyIlluminance,
                        skyTranslucents
                    );
                
                #elif AIR_FOG == 2

                    // Approximation

                    computeAirFogApproximation(
                        scatteringBack, transmittanceBack,
                        scenePosition0,
                        VdotL,
                        directIlluminanceFinal, skyIlluminance,
                        skyLight, skyTranslucents
                    );
                
                #endif

            }

            // Apply back fog

            lightingOut = lightingOut * transmittanceBack + scatteringBack;
        }

        //////////////////////////////////////////////////////////
        /*------------------ ALPHA BLENDING --------------------*/
        //////////////////////////////////////////////////////////

        // Elements from gbuffers_basic
        vec4 basic = texture(GBUFFERS_BASIC_BUFFER, vertexCoords);

        bool isEnchantmentGlint = basic.a >= 0.0 && basic.a <= 0.03;
        bool isDamageOverlay    = basic.a > 0.03 && basic.a <= 0.06;

        bool isHand = depth0 < handDepth;

        // Basic elements blending

        if (isEnchantmentGlint) {

            float glintBlendingFactor = alphaBlendedLighting.a > 0.0 ? 1.0 : float(!isHand || basic.a > 0.0);
            
            lightingOut += basic.rgb * invExposure * glintBlendingFactor * ENCHANTMENT_GLINT_STRENGTH;

        } else if (!isHand) {

            if (isDamageOverlay) {
                lightingOut = basic.rgb * lightingOut;
                
            } else {
                lightingOut = mix(lightingOut, basic.rgb * invExposure, basic.a);
            }

        }

        // Apply exposure to output to preserve HDR scale

        lightingOut *= exposure;
    }

#endif
