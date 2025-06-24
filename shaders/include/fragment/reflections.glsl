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

vec3 sampleHitColor(vec2 hitCoords) {
    return texture(ACCUMULATION_BUFFER, hitCoords * RENDER_SCALE).rgb;
}

vec3 sampleSkyColor(vec2 hitCoords, vec3 reflected, float skylight) {
    #if defined WORLD_OVERWORLD || defined WORLD_END
        vec2 coords     = projectSphere(normalize(mat3(gbufferModelViewInverse) * reflected));
        vec3 atmosphere = texture(ATMOSPHERE_BUFFER, saturate(coords)).rgb;

        vec4 clouds = vec4(0.0, 0.0, 0.0, 1.0);
        
        #if defined WORLD_OVERWORLD && CLOUDS_LAYER0_ENABLED == 1 || CLOUDS_LAYER1_ENABLED == 1
            vec3 cloudsBuffer;

            if (saturate(hitCoords) == hitCoords) {
                cloudsBuffer = texture(CLOUDS_BUFFER, hitCoords).rgb;
            } else {
                #if CLOUDMAP == 1
                    cloudsBuffer = textureLodLinearRGB(CLOUDMAP_BUFFER, saturate(coords * CLOUDMAP_SCALE), ivec2(textureSize(CLOUDMAP_BUFFER, 0)), 0).rgb;
                #else
                    cloudsBuffer = vec3(0.0, 0.0, 1.0);
                #endif
            }

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

    vec3 computeRoughReflections(bool dhFragment, mat4 projection, vec3 viewPosition, Material material, out float rayLength) {
        float alphaSq = maxEps(material.roughness * material.roughness);

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
                if (dhFragment) {
                    hit = float(raytrace(dhDepthTex0, projection, viewPosition, rayDirection, REFLECTIONS_STEPS, jitter, RENDER_SCALE, hitPosition, sampleRayLength));
                } else {
                    hit = float(raytrace(depthtex0, projection, viewPosition, rayDirection, REFLECTIONS_STEPS, jitter, RENDER_SCALE, hitPosition, sampleRayLength));
                }
            }

            #if defined REFLECTIONS_SKY_FALLBACK
                vec3 fallback = hitPosition.z >= handDepth ? sampleSkyColor(hitPosition.xy, rayDirection, skylight) : vec3(0.0);
            #else
                vec3 fallback = vec3(0.0);
            #endif

            vec3 fresnel;
            if (isEyeInWater == 1 || material.id == WATER_ID) {
                fresnel = fresnelDielectricDielectric_R(MdotV, vec3(airIOR), vec3(1.333));
            } else {
                fresnel = fresnelDielectricConductor(MdotV, material.N / airIOR, material.K / airIOR);
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

    vec3 computeSmoothReflections(bool dhFragment, mat4 projection, vec3 viewPosition, Material material, out float rayLength) {

        float alphaSq = maxEps(material.roughness * material.roughness);

        float skylight = getSkylightFalloff(material.lightmap.y);

        vec3  viewDirection = normalize(viewPosition);
        float NdotV         = dot(material.normal, -viewDirection);
        vec3  rayDirection  = viewDirection + 2.0 * NdotV * material.normal; 
        float NdotL         = abs(dot(material.normal, rayDirection));

        float hit;
        vec3 hitPosition;

        if (NdotL > 0.0) {
            if (dhFragment) {
                hit = float(raytrace(dhDepthTex0, projection, viewPosition, rayDirection, REFLECTIONS_STEPS, jitter, RENDER_SCALE, hitPosition, rayLength));
            } else {
                hit = float(raytrace(depthtex0, projection, viewPosition, rayDirection, REFLECTIONS_STEPS, jitter, RENDER_SCALE, hitPosition, rayLength));
            }
        }

        #if defined REFLECTIONS_SKY_FALLBACK
            vec3 fallback = sampleSkyColor(hitPosition.xy, rayDirection, skylight);
        #else
            vec3 fallback = vec3(0.0);
        #endif

        vec3 fresnel;
        if (isEyeInWater == 1 || material.id == WATER_ID) {
            fresnel = fresnelDielectricDielectric_R(NdotV, vec3(airIOR), vec3(1.333));
        } else {
            fresnel = fresnelDielectricConductor(NdotL, material.N / airIOR, material.K / airIOR);
        }

        float G1 = G1_Smith_GGX(NdotV, alphaSq);
        float G2 = G2_Smith_Height_Correlated(NdotV, NdotL, alphaSq);

        float energyCompensation = energyCompensationFactor(NdotV, NdotL, alphaSq);

        return mix(fallback, sampleHitColor(hitPosition.xy), hit) * fresnel * energyCompensation * G2 / G1;
    }

#endif
