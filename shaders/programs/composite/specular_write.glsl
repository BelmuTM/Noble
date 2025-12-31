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

/* RENDERTARGETS: 0 */

layout (location = 0) out vec3 lighting;

in vec2 textureCoords;
in vec2 vertexCoords;

#include "/settings.glsl"
#include "/include/taau_scale.glsl"

#include "/include/common.glsl"

#include "/include/utility/rng.glsl"

#include "/include/atmospherics/constants.glsl"

#include "/include/utility/phase.glsl"
#include "/include/utility/sampling.glsl"

#include "/include/fragment/brdf.glsl"
#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/shadows.glsl"

#include "/include/atmospherics/celestial.glsl"

#if REFRACTIONS > 0
    #include "/include/fragment/refractions.glsl"
#endif

#include "/include/post/exposure.glsl"

#if TAA == 1
    #include "/include/post/grading.glsl"
#endif

void main() {
    lighting = vec3(0.0);

    #if DOWNSCALED_RENDERING == 1
        vec2 fragCoords = gl_FragCoord.xy * texelSize;
        if (!insideScreenBounds(fragCoords, RENDER_SCALE)) { discard; return; }
    #endif

    vec3 coords = vec3(vertexCoords, 0.0);

    vec3 sunSpecular = vec3(0.0), envSpecular = vec3(0.0);

    bool  modFragment = false;
    float depth       = texture(depthtex0, vertexCoords).r;

    mat4 projection        = gbufferProjection;
    mat4 projectionInverse = gbufferProjectionInverse;

    float nearPlane = near;
    float farPlane  = far;

    #if defined CHUNK_LOADER_MOD_ENABLED
        if (depth >= 1.0) {
            modFragment = true;

            #if defined VOXY
                depth = texture(modDepthTex0, textureCoords).r;
            #else
                depth = texture(modDepthTex0, vertexCoords).r;
            #endif
                    
            projection        = modProjection;
            projectionInverse = modProjectionInverse;
        
            nearPlane = modNearPlane;
            farPlane  = modFarPlane;
        }
    #endif

    vec3 viewPosition0 = screenToView(vec3(textureCoords, depth), projectionInverse, true);

    vec4 blendedLighting = texture(MAIN_BUFFER, vertexCoords);

    // Terrain Fragments
    if (depth < 1.0) {

        Material material = getMaterial(vertexCoords);

        if (material.F0 * maxFloat8 <= labPBRMetals) {
            lighting = exp2(blendedLighting.rgb) - 1.0;
        }

        vec3 viewPosition1 = screenToView(vec3(textureCoords, material.depth1), projectionInverse, true);

        vec3 directIlluminance = vec3(0.0);
    
        #if defined WORLD_OVERWORLD || defined WORLD_END
            directIlluminance = texelFetch(IRRADIANCE_BUFFER, ivec2(0), 0).rgb;

            #if defined WORLD_OVERWORLD && defined SUNLIGHT_LEAKING_FIX
                directIlluminance *= float(material.lightmap.y > EPS || isEyeInWater == 1);
            #endif
        #endif

        //////////////////////////////////////////////////////////
        /*-------------------- REFRACTIONS ---------------------*/
        //////////////////////////////////////////////////////////

        #if REFRACTIONS > 0
            if (material.depth0 != material.depth1 && material.F0 > EPS) {
                lighting = computeRefractions(modFragment, projection, projectionInverse, viewPosition0, viewPosition1, material, coords);
            }
        #endif

        //////////////////////////////////////////////////////////
        /*-------------------- REFLECTIONS ---------------------*/
        //////////////////////////////////////////////////////////

        #if SPECULAR == 1
            vec3 visibility = vec3(1.0);

            if (!modFragment) {
                visibility = texture(SHADOWMAP_BUFFER, max(coords.xy, texelSize)).rgb;

                if (material.id == WATER_ID) {
                    visibility = material.albedo;
                }
            }

            #if defined WORLD_OVERWORLD && CLOUDS_SHADOWS == 1 && CLOUDS_LAYER0_ENABLED == 1
                visibility *= getCloudsShadows(viewToScene(viewPosition0));
            #endif

            if (visibility != vec3(0.0) && material.F0 > EPS) {
                sunSpecular = computeSpecular(material, -normalize(viewPosition0), shadowLightVector) * directIlluminance;
            }
        #endif

        #if REFLECTIONS > 0
            envSpecular = texture(REFLECTIONS_BUFFER, vertexCoords).rgb;
        #endif

    } else {
        // Sky Fragments

        lighting  = exp2(blendedLighting.rgb) - 1.0;
        lighting += renderCelestialBodies(vertexCoords, viewPosition0);
    }

    //////////////////////////////////////////////////////////
    /*--------------------- FOG FILTER ---------------------*/
    //////////////////////////////////////////////////////////

    vec3 scattering    = vec3(0.0);
    vec3 transmittance = vec3(0.0);

    /*
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
    */

    scattering    = decodeRGBE(texture(FOG_BUFFER, coords.xy).r);
    transmittance = decodeRGBE(texture(FOG_BUFFER, coords.xy).g);
    
    if (isEyeInWater == 1) {
        lighting += sunSpecular;
        lighting += envSpecular;
        lighting  = mix(lighting * transmittance + scattering, lighting, blendedLighting.a);
    } else {
        lighting  = mix(lighting * transmittance + scattering, lighting, blendedLighting.a);
        lighting += sunSpecular;
        lighting += envSpecular;
    }

    //////////////////////////////////////////////////////////
    /*------------------ ALPHA BLENDING --------------------*/
    //////////////////////////////////////////////////////////

    vec4 basic = texture(GBUFFERS_BASIC_BUFFER, vertexCoords);

    bool isEnchantmentGlint = basic.a >= 0.0 && basic.a <= 0.05;
    bool isDamageOverlay    = basic.a > 0.05 && basic.a <= 0.1;

    bool isHand = depth < handDepth;

    float exposure = 1.0;

    if (isEnchantmentGlint || (!isEnchantmentGlint && !isDamageOverlay))
        exposure = computeExposure(texelFetch(HISTORY_BUFFER, ivec2(0), 0).a);

    if (isEnchantmentGlint) {
        if ((isHand && basic.a > 0.0 && basic.a <= 0.05) || (!isHand && basic.a == 0.0)) {
            lighting.rgb += basic.rgb / exposure;
        }
    } else if (isDamageOverlay) {
        if (!isHand) lighting.rgb = 2.0 * basic.rgb * lighting.rgb;
    } else {
        if (!isHand) lighting.rgb = mix(lighting.rgb, basic.rgb / exposure, basic.a);
    }

    //////////////////////////////////////////////////////////
    /*---------------- TAA PRE-TONEMAPPING -----------------*/
    //////////////////////////////////////////////////////////

    #if TAA == 1
        lighting = lighting * computeExposure(texelFetch(HISTORY_BUFFER, ivec2(0), 0).a);
        lighting = reinhard(lighting);
    #endif
}
