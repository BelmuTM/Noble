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

    void main() {
        gl_Position    = vec4(gl_Vertex.xy * 2.0 - 1.0, 1.0, 1.0);
        gl_Position.xy = gl_Position.xy * RENDER_SCALE + (RENDER_SCALE - 1.0) * gl_Position.w; + (RENDER_SCALE - 1.0);
        textureCoords  = gl_Vertex.xy;
        vertexCoords   = gl_Vertex.xy * RENDER_SCALE;

        #if defined WORLD_OVERWORLD || defined WORLD_END

            directIlluminance = decodeLog(texelFetch(IRRADIANCE_BUFFER, ivec2(0, 0), 0).rgb);

        #endif
    }

#elif defined STAGE_FRAGMENT

    /* RENDERTARGETS: 0 */

    layout (location = 0) out vec3 lightingOut;

    in vec2 textureCoords;
    in vec2 vertexCoords;

    flat in vec3 directIlluminance;

    #include "/include/utility/rng.glsl"

    #include "/include/atmospherics/constants.glsl"

    #include "/include/utility/phase.glsl"
    #include "/include/utility/sampling.glsl"

    #include "/include/material/brdf.glsl"
    #include "/include/fragment/raytracer.glsl"
    #include "/include/fragment/shadows.glsl"

    #include "/include/atmospherics/celestial.glsl"

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

        vec3 coords = vec3(vertexCoords, 0.0);

        vec3 sunSpecular = vec3(0.0), envSpecular = vec3(0.0);

        bool modFragment = false;

        float depth0 = texture(depthtex0, vertexCoords).r;
        float depth1 = texture(depthtex1, vertexCoords).r;

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

        vec4 blendedLighting = texture(MAIN_BUFFER, vertexCoords);

        // Terrain Fragments
        if (depth0 < 1.0) {

            bool isOpaque = abs(depth0 - depth1) < 1e-6;

            Material material = getMaterial(vertexCoords);

            if (material.F0 * maxFloat8 <= labPBRMetals) {
                lightingOut = decodeLog(blendedLighting.rgb);
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
                        coords
                    );

                }

            #endif

            //////////////////////////////////////////////////////////
            /*-------------------- REFLECTIONS ---------------------*/
            //////////////////////////////////////////////////////////

            #if SPECULAR == 1

                vec3 visibility = vec3(1.0);

                vec3 directIlluminanceSpecular = directIlluminance;

                #if defined WORLD_OVERWORLD || defined WORLD_END

                    #if defined WORLD_OVERWORLD

                        vec3 scenePosition0 = viewToWorld(viewPosition0);

                        #if SHADOWS > 0

                            if (!modFragment) {

                                if (isOpaque) {
                                    visibility = texture(SHADOWMAP_BUFFER, max(coords.xy, texelSize)).rgb;

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

                if (any(greaterThan(visibility, vec3(EPS))) && material.F0 > EPS) {

                    sunSpecular = computeSpecular(
                        -normalize(viewPosition0),
                        shadowLightVector,
                        material.normal,
                        material.N,
                        material.K,
                        material.alpha
                    ) 
                    * directIlluminanceSpecular;

                }

            #endif

            #if REFLECTIONS > 0
                envSpecular = texture(REFLECTIONS_BUFFER, vertexCoords).rgb;
            #endif

        } else {
            
            // Sky Fragments
            lightingOut = decodeLog(blendedLighting.rgb);
        }

        //////////////////////////////////////////////////////////
        /*--------------------- FOG FILTER ---------------------*/
        //////////////////////////////////////////////////////////

        vec3 scattering    = vec3(0.0);
        vec3 transmittance = vec3(0.0);

        #if AIR_FOG_FILTER == 1

            float totalWeight = 0.0;

            const int filterSize = 2;

            for (int x = -filterSize; x <= filterSize; x++) {
                for (int y = -filterSize; y <= filterSize; y++) {
                    
                    vec2  sampleCoords = coords.xy + vec2(x, y) * texelSize * 2.0;
                    uvec2 packedFog    = texture(FOG_BUFFER, sampleCoords).rg;

                    float weight = gaussianDistribution2D(vec2(x, y), 1.0);

                    float linearDepth;
                    float linearSampleDepth;

                    if (modFragment) {
                        linearDepth       = texture(modDepthTex1, coords.xy).r;
                        linearSampleDepth = texture(modDepthTex1, sampleCoords).r;
                    } else {
                        linearDepth       = texture(depthtex1, coords.xy).r;
                        linearSampleDepth = texture(depthtex1, sampleCoords).r;
                    }

                    linearDepth       = linearizeDepth(linearDepth, nearPlane, farPlane);
                    linearSampleDepth = linearizeDepth(linearSampleDepth, nearPlane, farPlane);

                    weight *= step(abs(linearDepth - linearSampleDepth) / max(linearDepth, linearSampleDepth), 0.1);
                    
                    scattering    += decodeRGBE(packedFog[0]) * weight;
                    transmittance += decodeRGBE(packedFog[1]) * weight;

                    totalWeight += weight;
                }
            }
            
            scattering    /= totalWeight;
            transmittance /= totalWeight;
        
        #else

            scattering    = decodeRGBE(texture(FOG_BUFFER, coords.xy).r);
            transmittance = decodeRGBE(texture(FOG_BUFFER, coords.xy).g);

        #endif
        
        if (isEyeInWater == 1) {
            lightingOut += sunSpecular;
            lightingOut += envSpecular;
            lightingOut  = mix(lightingOut * transmittance + scattering, lightingOut, saturate(blendedLighting.a));
        } else {
            lightingOut  = mix(lightingOut * transmittance + scattering, lightingOut, saturate(blendedLighting.a));
            lightingOut += sunSpecular;
            lightingOut += envSpecular;
        }

        //////////////////////////////////////////////////////////
        /*------------------ ALPHA BLENDING --------------------*/
        //////////////////////////////////////////////////////////

        vec4 basic = texture(GBUFFERS_BASIC_BUFFER, coords.xy);

        bool isEnchantmentGlint = basic.a >= 0.0 && basic.a <= 0.05;
        bool isDamageOverlay    = basic.a > 0.05 && basic.a <= 0.1;

        bool isHand = depth0 < handDepth;

        float exposure = 1.0;

        if (isEnchantmentGlint || (!isEnchantmentGlint && !isDamageOverlay))
            exposure = computeExposure(texelFetch(HISTORY_BUFFER, ivec2(0), 0).a);

        if (isEnchantmentGlint) {

            float glintBlendingFactor = blendedLighting.a > 0.0 ? 1.0 - blendedLighting.a : float(!isHand || basic.a > 0.0);
            
            lightingOut.rgb += basic.rgb / exposure * glintBlendingFactor * ENCHANTMENT_GLINT_STRENGTH;

        } else if (!isHand) {

            if (isDamageOverlay) {
                lightingOut.rgb = basic.rgb * lightingOut.rgb;
                
            } else {
                lightingOut.rgb = mix(lightingOut.rgb, basic.rgb / exposure, basic.a);
            }

        }
    }

#endif
