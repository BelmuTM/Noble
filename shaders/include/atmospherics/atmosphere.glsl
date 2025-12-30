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

/*
    [Credits]:
        Jessie - help with atmospheric scattering and providing ozone cross section approximation (https://github.com/Jessie-LC)
        Zombye - sky illuminance sampling approximation (https://github.com/zombye)
        
    [References]:
        Nishita, T. (1993). Display of the earth taking into account atmospheric scattering. http://nishitalab.org/user/nis/cdrom/sig93_nis.pdf
        Elek, O. (2009). Rendering Parametrizable Planetary Atmospheres with Multiple Scattering in Real-Time. https://old.cescg.org/CESCG-2009/papers/PragueCUNI-Elek-Oskar09.pdf
        Jimenez et al. (2016). Practical Real-Time Strategies for Accurate Indirect Occlusion. https://www.activision.com/cdn/research/Practical_Real_Time_Strategies_for_Accurate_Indirect_Occlusion_NEW%20VERSION_COLOR.pdf 
        Mayaux, B. (n.d.). Spherical Harmonics. https://patapom.com/blog/SHPortal/
        Wikipedia. (2023). Table of spherical harmonics. https://en.wikipedia.org/wiki/Table_of_spherical_harmonics
*/

vec3 getAtmosphereDensities(float centerDist) {
    float altitudeKm = (centerDist - planetRadius) * 1e-3;
    vec2 rayleighMie = exp(altitudeKm / -(scaleHeights * 1e-3));

    // Ozone approximation from Jessie
    float o1 = 25.0 *     exp(( 0.0 - altitudeKm) * rcp(  8.0));
    float o2 = 30.0 * pow(exp((18.0 - altitudeKm) * rcp( 80.0)), altitudeKm - 18.0);
    float o3 = 75.0 * pow(exp((25.3 - altitudeKm) * rcp( 35.0)), altitudeKm - 25.3);
    float o4 = 50.0 * pow(exp((30.0 - altitudeKm) * rcp(150.0)), altitudeKm - 30.0);
    float ozone = (o1 + o2 + o3 + o4) * rcp(134.628);

    return vec3(rayleighMie, ozone);
}

vec3 evaluateAtmosphereTransmittance(vec3 rayOrigin, vec3 lightDir, mat3x3 attenuationCoefficients) {
    float stepSize   = intersectSphere(rayOrigin, lightDir, atmosphereUpperRadius).y * rcp(ATMOSPHERE_TRANSMITTANCE_STEPS);
    vec3 increment   = lightDir * stepSize;
    vec3 rayPosition = rayOrigin + increment * 0.5;

    vec3 accumAirmass = vec3(0.0);
    for (int i = 0; i < ATMOSPHERE_TRANSMITTANCE_STEPS; i++, rayPosition += increment) {
        accumAirmass += getAtmosphereDensities(length(rayPosition)) * stepSize;
    }
    return exp(-attenuationCoefficients * accumAirmass);
}

#if defined STAGE_FRAGMENT

    vec3 evaluateAtmosphericScattering(vec3 rayDirection, vec3 skyIlluminance) {
        vec2 dists = intersectSphericalShell(atmosphereRayPosition, rayDirection, atmosphereLowerRadius, atmosphereUpperRadius);
        if (dists.y < 0.0) return vec3(0.0);

        float stepSize   = (dists.y - dists.x) * rcp(ATMOSPHERE_SCATTERING_STEPS);
        vec3 increment   = rayDirection * stepSize;
        vec3 rayPosition = atmosphereRayPosition + increment * 0.5;

        #if defined WORLD_OVERWORLD

            vec2 VdotL = vec2(dot(rayDirection, sunVector), dot(rayDirection, moonVector));
            vec4 phase = vec4(
                vec2(rayleighPhase(VdotL.x), kleinNishinaPhase(VdotL.x, mieAnisotropyFactor)), 
                vec2(rayleighPhase(VdotL.y), kleinNishinaPhase(VdotL.y, mieAnisotropyFactor))
            );

            mat2x3 scatteringCoefficients  = atmosphereScatteringCoefficients;
            mat3x3 attenuationCoefficients = atmosphereAttenuationCoefficients;

        #elif defined WORLD_END

            float VdotL = dot(rayDirection, starVector);
            vec2  phase = vec2(rayleighPhase(VdotL), kleinNishinaPhase(VdotL, mieAnisotropyFactor));

            mat2x3 scatteringCoefficients  = atmosphereScatteringCoefficientsEnd;
            mat3x3 attenuationCoefficients = atmosphereAttenuationCoefficientsEnd;

        #endif

        mat2x3 scattering = mat2x3(vec3(0.0), vec3(0.0)); vec3 multipleScattering = vec3(0.0); vec3 transmittance = vec3(1.0);
    
        for (int i = 0; i < ATMOSPHERE_SCATTERING_STEPS; i++, rayPosition += increment) {

            #if defined WORLD_OVERWORLD
                vec3 airmass          = getAtmosphereDensities(length(rayPosition)) * stepSize;
                vec3 stepOpticalDepth = atmosphereAttenuationCoefficients * airmass;
            #elif defined WORLD_END
                float altitudeKm       = (length(rayPosition) - planetRadius) * 1e-3;
                vec3  airmass          = exp(altitudeKm / -(vec3(scaleHeights, 5e3) * 1e-3)) * stepSize;
                vec3  stepOpticalDepth = atmosphereAttenuationCoefficientsEnd * airmass;
            #endif

            vec3 stepTransmittance  = exp(-stepOpticalDepth);
            vec3 visibleScattering  = transmittance * saturate((stepTransmittance - 1.0) / -stepOpticalDepth);

            #if defined WORLD_OVERWORLD

                vec3 sunStepScattering  = scatteringCoefficients * (airmass.xy * phase.xy) * visibleScattering;
                vec3 moonStepScattering = scatteringCoefficients * (airmass.xy * phase.zw) * visibleScattering;

                scattering[0] += sunStepScattering  * evaluateAtmosphereTransmittance(rayPosition, sunVector , attenuationCoefficients);
                scattering[1] += moonStepScattering * evaluateAtmosphereTransmittance(rayPosition, moonVector, attenuationCoefficients);

            #elif defined WORLD_END

                vec3 starStepScattering = scatteringCoefficients * (airmass.xy * phase) * visibleScattering;
                
                scattering[0] += starStepScattering * evaluateAtmosphereTransmittance(rayPosition, starVector, attenuationCoefficients);

            #endif

            vec3 stepScattering    = scatteringCoefficients * airmass.xy;
            vec3 stepScatterAlbedo = stepScattering / stepOpticalDepth;

            vec3 multScatteringFactor = stepScatterAlbedo * 0.84;
            vec3 multScatteringEnergy = multScatteringFactor / (1.0 - multScatteringFactor);
                 multipleScattering  += multScatteringEnergy * visibleScattering * stepScattering;

            transmittance *= stepTransmittance;
        }
        
        multipleScattering *= skyIlluminance * isotropicPhase;

        #if defined WORLD_OVERWORLD

            scattering[0] *= sunIrradiance;
            scattering[1] *= moonIrradiance;

        #elif defined WORLD_END

            scattering[0] *= starIrradiance;

        #endif
    
        return scattering[0] + scattering[1] + multipleScattering;
    }

#endif

vec3 evaluateDirectIlluminance() {
    vec3 directIlluminance = vec3(0.0);

    #if defined WORLD_OVERWORLD

        directIlluminance += evaluateAtmosphereTransmittance(atmosphereRayPosition, sunVector , atmosphereAttenuationCoefficients) * sunIrradiance;
        directIlluminance += evaluateAtmosphereTransmittance(atmosphereRayPosition, moonVector, atmosphereAttenuationCoefficients) * moonIrradiance;

    #elif defined WORLD_END

        directIlluminance += evaluateAtmosphereTransmittance(atmosphereRayPosition, starVector, atmosphereAttenuationCoefficientsEnd) * starIrradiance;

    #endif

    return max0(directIlluminance);
}

vec3 evaluateUniformSkyIrradianceApproximation() {
    vec3 skyIlluminance = vec3(0.0);

    #if defined WORLD_OVERWORLD || defined WORLD_END

        const ivec2 samples        = ivec2(16);
        const float invSampleCount = 1.0 / float(samples.x * samples.y);

        for (int x = 0; x < samples.x; x++) {
            for (int y = 0; y < samples.y; y++) {
                vec2 uv = (vec2(x,y) + 0.5) / samples;

                float phi   = TAU * uv.x;
                float theta = 0.5 * PI * uv.y;

                float cosTheta = cos(theta);
                float sinTheta = sin(theta);

                vec3 radiance = texture(ATMOSPHERE_BUFFER, uv).rgb;

                skyIlluminance += radiance * cosTheta * sinTheta;
            }
        }

        skyIlluminance *= PI * PI * invSampleCount;

    #endif

    return max0(skyIlluminance);
}

mat3[2] evaluateDirectionalSkyIrradianceApproximation() {
    mat3[2] skyIlluminance = mat3[2](mat3(0.0), mat3(0.0));

    #if defined WORLD_OVERWORLD || defined WORLD_END

        const ivec2 samples        = ivec2(8);
        const float invSampleCount = 1.0 / float(samples.x * samples.y);

        for (int x = 0; x < samples.x; x++) {
            for (int y = 0; y < samples.y; y++) {
                vec2 uv = (vec2(x, y) + 0.5) / samples;

                float phi   = TAU      * uv.x;
                float theta = 0.5 * PI * uv.y;

                float cosTheta = cos(theta);
                float sinTheta = sin(theta);

                vec3 direction = vec3(
                    sin(phi) * sinTheta,
                    cosTheta,
                    cos(phi) * sinTheta
                );

                vec3 radiance = vec3(luminance(texture(ATMOSPHERE_BUFFER, uv).rgb));

                vec3 contribution = radiance * cosTheta * sinTheta;

                // Positive lobes
                skyIlluminance[0][0] += contribution * max(direction.x, 0.0);
                skyIlluminance[0][1] += contribution * max(direction.y, 0.0);
                skyIlluminance[0][2] += contribution * max(direction.z, 0.0);

                // Negative lobes
                skyIlluminance[1][0] += contribution * max(-direction.x, 0.0);
                skyIlluminance[1][1] += contribution * max(-direction.y, 0.0);
                skyIlluminance[1][2] += contribution * max(-direction.z, 0.0);
            }
        }

        const float normalization = PI * PI * invSampleCount;

        skyIlluminance[0] *= normalization;
        skyIlluminance[1] *= normalization;

    #endif

    return skyIlluminance;
}

vec3 evaluateSkylight(vec3 normal, mat3[2] skylight) {
    vec3 octahedronPoint = normal / dot(abs(normal), vec3(1.0));
    vec3 positive = saturate(octahedronPoint), negative = saturate(-octahedronPoint);
    
    return skylight[0][0] * positive.x + skylight[0][1] * positive.y + skylight[0][2] * positive.z
         + skylight[1][0] * negative.x + skylight[1][1] * negative.y + skylight[1][2] * negative.z;
}

// Spherical Harmonics Coefficients for 2 orders
float[9] calculateSphericalHarmonicsCoefficients(vec3 wi) {
    return float[9](
        0.28209479,

        0.48860251 * wi.y,
        0.48860251 * wi.z,
        0.48860251 * wi.x,

        1.09254843 * wi.x * wi.y,
        1.09254843 * wi.y * wi.z,
        0.31539156 * (3.0 * wi.z * wi.z - 1.0),
        1.09254843 * wi.x * wi.z,
        0.54627421 * (wi.x * wi.x - wi.y * wi.y)
    );
}

void evaluateUniformSkyIrradiance(out vec3[9] irradiance) {
    for (int i = 0; i < 9; i++) irradiance[i] = vec3(0.0);

    #if defined WORLD_OVERWORLD || defined WORLD_END

        const ivec2 samples        = ivec2(8);
        const float invSampleCount = 1.0 / float(samples.x * samples.y);

        for (int x = 0; x < samples.x; x++) {
            for (int y = 0; y < samples.y; y++) {
                vec2 uv = (vec2(x, y) + 0.5) / samples;

                float phi   = TAU      * uv.x;
                float theta = 0.5 * PI * uv.y;

                float cosTheta = cos(theta);
                float sinTheta = sin(theta);

                vec3 direction = vec3(sin(phi) * sinTheta, cos(theta), cos(phi) * sinTheta);

                vec3 radiance = vec3(luminance(texture(ATMOSPHERE_BUFFER, uv).rgb));

                float[9] sh = calculateSphericalHarmonicsCoefficients(direction);

                for (int i = 0; i < 9; i++)
                    irradiance[i] += radiance * sh[i] * cosTheta * sinTheta;
            }
        }

        const float normalization = PI * PI * invSampleCount;

        for (int i = 0; i < 9; i++) irradiance[i] *= normalization;

    #endif
}

vec3[9] sampleUniformSkyIrradiance() {
    return vec3[9](
        texelFetch(IRRADIANCE_BUFFER, ivec2(1, 0), 0).rgb,
        texelFetch(IRRADIANCE_BUFFER, ivec2(2, 0), 0).rgb,
        texelFetch(IRRADIANCE_BUFFER, ivec2(3, 0), 0).rgb,
        texelFetch(IRRADIANCE_BUFFER, ivec2(4, 0), 0).rgb,
        texelFetch(IRRADIANCE_BUFFER, ivec2(5, 0), 0).rgb,
        texelFetch(IRRADIANCE_BUFFER, ivec2(6, 0), 0).rgb,
        texelFetch(IRRADIANCE_BUFFER, ivec2(7, 0), 0).rgb,
        texelFetch(IRRADIANCE_BUFFER, ivec2(8, 0), 0).rgb,
        texelFetch(IRRADIANCE_BUFFER, ivec2(9, 0), 0).rgb
    );
}

vec3 evaluateDirectionalSkyIrradiance(vec3[9] irradiance, vec3 bentNormal, float visibility) {
    float[9] sh = calculateSphericalHarmonicsCoefficients(bentNormal);

    // Lambertian convolution
    const float A0 = PI;
    const float A1 = TAU / 3.0;
    const float A2 = PI  / 4.0;

    vec3 result = irradiance[0] * A0 * sh[0]
                + (irradiance[1] * sh[1] + irradiance[2] * sh[2] + irradiance[3] * sh[3]) * A1
                + (irradiance[4] * sh[4] + irradiance[5] * sh[5] + irradiance[6] * sh[6] + irradiance[7] * sh[7] + irradiance[8] * sh[8]) * A2;

    return result * visibility;
}
