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

    #include "/include/atmospherics/atmosphere_header.glsl"

    #include "/include/fragment/shadows.glsl"
    
    #include "/include/atmospherics/fog.glsl"

    #include "/include/post/exposure.glsl"

    void main() {
        
        lightingOut = vec3(0.0);

        #if DOWNSCALED_RENDERING == 1
            vec2 fragCoords = gl_FragCoord.xy * texelSize;
            if (!insideScreenBounds(fragCoords, RENDER_SCALE)) { return; }
        #endif

        // Inverting pre-exposure to retrieve range

        float rcpExposure = 1.0 / CURRENT_EXPOSURE();

        vec3 background = texture(MAIN_BUFFER, vertexCoords).rgb * rcpExposure;

        // Fog setup

        float depth0 = texture(depthtex0, vertexCoords).r;
        float depth1 = texture(depthtex1, vertexCoords).r;

        float farPlane = far;

        mat4 projectionInverse = gbufferProjectionInverse;

        #if defined CHUNK_LOADER_MOD_ENABLED

            farPlane = modFarPlane;

            #if defined VOXY
                float modDepth1 = texture(modDepthTex1, textureCoords).r;
            #else
                float modDepth1 = texture(modDepthTex1, vertexCoords).r;
            #endif

            if (depth1 >= 1.0 && depth0 >= 1.0) {
        
                #if defined VOXY
                    depth0 = texture(modDepthTex0, textureCoords).r;
                    depth1 = modDepth1;
                #else
                    depth0 = texture(modDepthTex0, vertexCoords).r;
                    depth1 = modDepth1;
                #endif
                
                projectionInverse = modProjectionInverse;
            }
            
        #endif

        vec3 viewPosition0  = screenToView(vec3(textureCoords, depth0), projectionInverse, true);
        vec3 viewPosition1  = screenToView(vec3(textureCoords, depth1), projectionInverse, true);
        vec3 scenePosition0 = viewToWorld(viewPosition0);
        
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

        bool skyTranslucents = depth1 == 1.0;

        //////////////////////////////////////////////////////////
        /*---------------- FRONT TO BACK FOG -------------------*/
        //////////////////////////////////////////////////////////

        vec3 scatteringBack    = vec3(0.0);
        vec3 transmittanceBack = vec3(1.0);

        if (depth0 < 1.0) {
            uvec4 dataTexture = texelFetch(GBUFFERS_DATA, ivec2(vertexCoords * viewSize), 0);

            float skylight = getSkylightFalloff(unpackLightmap(dataTexture.x).y);

            if (viewPosition0.z != viewPosition1.z) {

                vec3 scenePosition1 = viewToWorld(viewPosition1);

                if (isEyeInWater != 1 && isWater(unpackId(dataTexture.x))) {

                    #if defined WORLD_OVERWORLD || defined WORLD_END

                        #if WATER_FOG == 0
                            computeWaterFogApproximation(scatteringBack, transmittanceBack, scenePosition0, scenePosition1, VdotL, directIlluminanceFinal, skyIlluminance, skylight);
                        #else
                            computeVolumetricWaterFog(scatteringBack, transmittanceBack, scenePosition0, scenePosition1, VdotL, directIlluminanceFinal, skyIlluminance, skylight, skyTranslucents);
                        #endif

                    #endif

                } else {

                    #if AIR_FOG == 1
                        computeVolumetricAirFog(scatteringBack, transmittanceBack, scenePosition0, scenePosition1, viewPosition0, farPlane, VdotL, directIlluminanceFinal, skyIlluminance, skyTranslucents);
                    #elif AIR_FOG == 2
                        computeAirFogApproximation(scatteringBack, transmittanceBack, viewPosition0, farPlane, VdotL, directIlluminanceFinal, skyIlluminance, skylight);
                    #endif

                }

            }
        }

        // Applying back fog

        lightingOut = background * transmittanceBack + scatteringBack;

        //////////////////////////////////////////////////////////
        /*------------------ ALPHA BLENDING --------------------*/
        //////////////////////////////////////////////////////////

        // Forward-rendered translucents
        vec4 translucents = texture(MAIN_BUFFER, vertexCoords);

        // Elements from gbuffers_basic
        vec4 basic = texture(GBUFFERS_BASIC_BUFFER, vertexCoords);

        bool isEnchantmentGlint = basic.a >= 0.0 && basic.a <= 0.05;
        bool isDamageOverlay    = basic.a > 0.05 && basic.a <= 0.1;

        bool isHand = depth0 < handDepth;

        // Basic elements blending

        if (isEnchantmentGlint) {

            float glintBlendingFactor = translucents.a > 0.0 ? 1.0 : float(!isHand || basic.a > 0.0);
            
            lightingOut += basic.rgb * rcpExposure * glintBlendingFactor * ENCHANTMENT_GLINT_STRENGTH;

        } else if (!isHand) {

            if (isDamageOverlay) {
                lightingOut = basic.rgb * lightingOut;
                
            } else {
                lightingOut = mix(lightingOut, basic.rgb * rcpExposure, basic.a);
            }

        }

        // Translucents blending

        lightingOut = mix(lightingOut, background, translucents.a);

        lightingOut /= rcpExposure;
    }

#endif
