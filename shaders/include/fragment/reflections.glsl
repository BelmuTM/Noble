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

vec3 sampleHitColor(vec2 hitCoords) {
    return exp2(texture(MAIN_BUFFER, hitCoords * RENDER_SCALE).rgb) - 1.0;
}

vec3 sampleSkyColor(vec2 hitCoords, vec3 reflected, float skylight) {
    #if defined WORLD_OVERWORLD || defined WORLD_END
        vec3 sceneDirection = normalize(mat3(gbufferModelViewInverse) * reflected);
        vec2 coords         = projectSphere(sceneDirection);

        vec3 atmosphere = sampleAtmosphere(sceneDirection, true, false);

        vec4 clouds = vec4(0.0, 0.0, 0.0, 1.0);
        
        #if defined WORLD_OVERWORLD && (CLOUDS_LAYER0_ENABLED == 1 || CLOUDS_LAYER1_ENABLED == 1)

            vec3 cloudsBuffer = vec3(0.0, 0.0, 1.0);
            #if CLOUDMAP == 1
                cloudsBuffer = textureCubic(CLOUDMAP_BUFFER, saturate(coords * CLOUDMAP_SCALE - bayer32(gl_FragCoord.xy) * 1e-3)).rgb;
            #endif

            clouds.rgb = cloudsBuffer.r * directIlluminance + cloudsBuffer.g * skyIlluminance;
            clouds.a   = cloudsBuffer.b;

        #endif

        return max0((atmosphere * clouds.a + clouds.rgb) * skylight);
    #else
        return vec3(0.0);
    #endif
}

float energyCompensationFactor(float NdotV, float NdotL, float alphaSq) {
    return 1.0 / (1.0 + lambda_Smith(NdotV, alphaSq) + lambda_Smith(NdotL, alphaSq));
}

float jitter = temporalBlueNoise(gl_FragCoord.xy);

#if REFLECTIONS == 1

    //////////////////////////////////////////////////////////
    /*------------------ ROUGH REFLECTIONS -----------------*/
    //////////////////////////////////////////////////////////

    vec3 computeRoughReflections(
        bool modFragment,
        mat4 projection,
        mat4 projectionInverse,
        vec3 viewPosition,
        Material material,
        out float rayLength
    ) {
        viewPosition += material.normal * 1e-2;

        float alphaSq = maxEps(material.roughness * material.roughness);

        vec3 eta  = material.N / airIOR;
        vec3 etaK = material.K / airIOR;

        float skylight = getSkylightFalloff(material.lightmap.y);

        vec3  viewDirection = normalize(viewPosition);
        mat3  tbn           = calculateTBN(material.normal);
        float NdotV         = dot(material.normal, -viewDirection);

        float G1 = G1_Smith_GGX(NdotV, alphaSq);

        vec3 tangentViewDirection = -viewDirection * tbn;

        vec3 reflection = vec3(0.0);

        for (int i = 0; i < ROUGH_REFLECTIONS_SAMPLES; i++) {
            vec3  microfacetNormal = tbn * sampleGGXVNDF(tangentViewDirection, rand2F(), material.roughness);
            float MdotV            = dot(microfacetNormal, -viewDirection);
            vec3  rayDirection     = viewDirection + 2.0 * MdotV * microfacetNormal;	
            float NdotL            = abs(dot(material.normal, rayDirection));

            float hit;
            vec3 hitPosition;
            float sampleRayLength;

            if (NdotL > 0.0) {
                if (modFragment) {
                    hit = float(raytrace(
                        modDepthTex0,
                        projection,
                        projectionInverse,
                        viewPosition,
                        rayDirection,
                        float(REFLECTIONS_STRIDE),
                        jitter,
                        RENDER_SCALE,
                        hitPosition,
                        sampleRayLength
                    ));
                } else {
                    hit = float(raytrace(
                        depthtex0,
                        projection,
                        projectionInverse,
                        viewPosition,
                        rayDirection,
                        float(REFLECTIONS_STRIDE),
                        jitter,
                        RENDER_SCALE,
                        hitPosition,
                        sampleRayLength
                    ));
                }
            }

            #if defined REFLECTIONS_SKY_FALLBACK
                vec3 fallback = sampleSkyColor(hitPosition.xy, rayDirection, skylight);
            #else
                vec3 fallback = vec3(0.0);
            #endif
            
            vec3 fresnel;
            if (isEyeInWater == 1 || isWater(material.id)) {
                fresnel = fresnelDielectricDielectric_R(MdotV, vec3(airIOR), vec3(1.333));
            } else {
                fresnel = fresnelDielectricConductor(MdotV, eta, etaK);
            }

            float G2 = G2_Smith_Height_Correlated(NdotV, NdotL, alphaSq);
            
            float energyCompensation = energyCompensationFactor(NdotV, NdotL, alphaSq);

            reflection += mix(fallback, sampleHitColor(hitPosition.xy), hit) * fresnel * energyCompensation * G2 / G1;

            rayLength += sampleRayLength;
        }
        
        rayLength /= ROUGH_REFLECTIONS_SAMPLES;

        return reflection / ROUGH_REFLECTIONS_SAMPLES;
    }

#elif REFLECTIONS == 2

    //////////////////////////////////////////////////////////
    /*------------------ SMOOTH REFLECTIONS ----------------*/
    //////////////////////////////////////////////////////////

    vec3 computeSmoothReflections(
        bool modFragment,
        mat4 projection,
        mat4 projectionInverse,
        vec3 viewPosition,
        Material material,
        out float rayLength
    ) {
        viewPosition += material.normal * 1e-2;

        float alphaSq = maxEps(material.roughness * material.roughness);

        vec3 eta  = material.N / airIOR;
        vec3 etaK = material.K / airIOR;

        float skylight = getSkylightFalloff(material.lightmap.y);

        vec3  viewDirection = normalize(viewPosition);
        float NdotV         = dot(material.normal, -viewDirection);
        vec3  rayDirection  = viewDirection + 2.0 * NdotV * material.normal; 
        float NdotL         = abs(dot(material.normal, rayDirection));

        float hit;
        vec3 hitPosition;

        if (NdotL > 0.0) {
            if (modFragment) {
                hit = float(raytrace(
                    modDepthTex0,
                    projection,
                    projectionInverse,
                    viewPosition,
                    rayDirection,
                    float(REFLECTIONS_STRIDE),
                    jitter,
                    RENDER_SCALE,
                    hitPosition,
                    rayLength
                ));
            } else {
                hit = float(raytrace(
                    depthtex0,
                    projection,
                    projectionInverse,
                    viewPosition,
                    rayDirection,
                    float(REFLECTIONS_STRIDE),
                    jitter,
                    RENDER_SCALE,
                    hitPosition,
                    rayLength
                ));
            }
        }

        #if defined REFLECTIONS_SKY_FALLBACK
            vec3 fallback = sampleSkyColor(hitPosition.xy, rayDirection, skylight);
        #else
            vec3 fallback = vec3(0.0);
        #endif

        vec3 fresnel;
        if (isEyeInWater == 1 || isWater(material.id)) {
            fresnel = fresnelDielectricDielectric_R(NdotV, vec3(airIOR), vec3(1.333));
        } else {
            fresnel = fresnelDielectricConductor(NdotV, eta, etaK);
        }

        float G1 = G1_Smith_GGX(NdotV, alphaSq);
        float G2 = G2_Smith_Height_Correlated(NdotV, NdotL, alphaSq);

        float energyCompensation = energyCompensationFactor(NdotV, NdotL, alphaSq);

        return mix(fallback, sampleHitColor(hitPosition.xy), hit) * fresnel * energyCompensation * G2 / G1;
    }

#endif
