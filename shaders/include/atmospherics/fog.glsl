/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

float dither = fract(frameTimeCounter + bayer256(gl_FragCoord.xy));

float calculateFogPhase(float cosTheta) {
    float forwardsLobe  = henyeyGreensteinPhase(cosTheta, fogForwardsLobe);
    float backwardsLobe = henyeyGreensteinPhase(cosTheta,-fogBackardsLobe);
    float forwardsPeak  = henyeyGreensteinPhase(cosTheta, fogForwardsPeak);

    return mix(mix(forwardsLobe, backwardsLobe, fogBackScatter), forwardsPeak, fogPeakWeight);
}

#if defined WORLD_OVERWORLD
    vec3 fogAttenuationCoefficients = vec3(fogExtinctionCoefficient);
    vec3 fogScatteringCoefficients  = vec3(fogScatteringCoefficient);
#elif defined WORLD_NETHER
    const vec3 fogAttenuationCoefficients = vec3(0.6, 0.4, 0.05);
    const vec3 fogScatteringCoefficients  = vec3(1.0, 0.3, 0.0);
#elif defined WORLD_END
    const vec3 fogAttenuationCoefficients = vec3(0.7, 0.5, 0.75);
    const vec3 fogScatteringCoefficients  = vec3(0.7, 0.3, 0.8);
#endif

#if AIR_FOG == 0
    void computeFogApproximation(out vec3 scatteringOut, out vec3 transmittanceOut, vec3 viewPosition, float VdotL, vec3 directIlluminance, vec3 skyIlluminance, float skylight, bool sky) {
        float airmass    = length(viewPosition) * 0.01 * (FOG_DENSITY * 10.0);
        transmittanceOut = exp(-fogAttenuationCoefficients * airmass);

        scatteringOut  = skyIlluminance    * isotropicPhase     * skylight;
        scatteringOut += directIlluminance * calculateFogPhase(VdotL) * skylight;
        scatteringOut *= fogScatteringCoefficients * ((1.0 - transmittanceOut) / fogAttenuationCoefficients);
    }

#else

    float getFogDensity(vec3 position) {
        #if defined WORLD_OVERWORLD
            const float fogAltitude   = FOG_ALTITUDE;
            const float fogThickness  = FOG_THICKNESS;
                  float densityFactor = wetness;
            const float densityMult   = 1.0;
        #elif defined WORLD_NETHER
            const float fogAltitude   = FOG_ALTITUDE - 34.0;
            const float fogThickness  = FOG_THICKNESS * 1.8;
            const float densityFactor = 1.0;
            const float densityMult   = 1.0;
        #elif defined WORLD_END
            const float fogAltitude   = FOG_ALTITUDE - 10.0;
            const float fogThickness  = (FOG_THICKNESS + 40.0) * 1.3;
            const float densityFactor = 1.0;
            const float densityMult   = 2.0;
        #endif

        float altitude   = (position.y - fogAltitude) * rcp(fogThickness);
        float shapeAlter = remap(altitude, 0.0, 0.2, 0.0, 1.0) * remap(altitude, 0.9, 1.0, 1.0, 0.0);

        /*
            CREDITS (density function):
            SixSeven: https://www.curseforge.com/minecraft/customization/voyager-shader-2-0
        */
        float shapeNoise  = FBM(position * 0.03, 3, 2.0);
              shapeNoise  = shapeNoise * shapeAlter * 0.4 - (2.0 * shapeAlter * altitude * 0.5 + 0.5);
              shapeNoise *= exp(-max0(position.y - fogAltitude) * 0.2);
        
        return saturate(shapeNoise) * mix(FOG_DENSITY, 1.0, densityFactor) * densityMult;
    }

    /*
    float getFogTransmittance(vec3 rayOrigin, vec3 lightDir) {
        const float stepSize = 1.0 / VL_TRANSMITTANCE_STEPS;
        vec3 increment   = lightDir * stepSize;
        vec3 rayPosition = rayOrigin + increment * 0.5;

        float accumAirmass = 0.0;
        for(int i = 0; i < VL_TRANSMITTANCE_STEPS; i++, rayPosition += increment) {
            accumAirmass += getFogDensity(rayPosition) * stepSize;
        }
        return exp(-fogExtinctionCoefficient * accumAirmass);
    }
    */

    void computeVolumetricAirFog(out vec3 scatteringOut, out vec3 transmittanceOut, vec3 startPosition, vec3 endPosition, vec3 viewPosition, float VdotL, vec3 directIlluminance, vec3 skyIlluminance, float skylight) {
        const float stepSize = 1.0 / VL_SCATTERING_STEPS;
        
        vec3 increment    = (endPosition - startPosition) * stepSize;
        vec3 rayPosition  = startPosition + increment * dither;
             rayPosition += cameraPosition;

        vec3 shadowStartPosition = worldToShadow(startPosition);
        vec3 shadowIncrement     = (worldToShadow(endPosition) - shadowStartPosition) * stepSize;
        vec3 shadowPosition      = shadowStartPosition + shadowIncrement * dither;

        float rayLength = length(increment);
        float phase     = calculateFogPhase(VdotL);

        float perspective = quintic(0.0, 1.0, exp2(-5e-4 * length(viewPosition)));

        mat2x3 scattering    = mat2x3(vec3(0.0), vec3(0.0)); 
        vec3   transmittance = vec3(1.0);

        for(int i = 0; i < VL_SCATTERING_STEPS; i++, rayPosition += increment, shadowPosition += shadowIncrement) {
            float density      = getFogDensity(rayPosition);
            float airmass      = density * rayLength;
            vec3  opticalDepth = fogAttenuationCoefficients * airmass;

            vec3 stepTransmittance = exp(-opticalDepth);
            vec3 visibleScattering = transmittance * saturate((stepTransmittance - 1.0) / -opticalDepth);

            vec3 stepScatteringDirect   = fogScatteringCoefficients * airmass * phase          * visibleScattering;
            vec3 stepScatteringIndirect = fogScatteringCoefficients * airmass * isotropicPhase * visibleScattering;

            #if defined WORLD_OVERWORLD
                vec3 shadowColor = getShadowColor(distortShadowSpace(shadowPosition) * 0.5 + 0.5);

                #if CLOUDS_SHADOWS == 1 && PRIMARY_CLOUDS == 1
                    shadowColor *= getCloudsShadows(rayPosition);
                #endif

                scattering[0] += stepScatteringDirect * shadowColor;
            #else
                scattering[0] += stepScatteringDirect;
            #endif

            scattering[1] += stepScatteringIndirect;
            transmittance *= perspective * stepTransmittance;
        }

        #if defined WORLD_OVERWORLD
            scattering[0] *= directIlluminance;
            scattering[1] *= skyIlluminance * skylight;
        #else
            scattering[0] *= directIlluminance;
            scattering[1] *= skyIlluminance;
        #endif

        scatteringOut    = scattering[0] + scattering[1];
        transmittanceOut = vec3(1.0);
    }
#endif

#if TONEMAP == ACES
    const vec3 waterAbsorptionCoefficients = (vec3(WATER_ABSORPTION_R, WATER_ABSORPTION_G, WATER_ABSORPTION_B) * 0.01) * SRGB_2_AP1_ALBEDO;
    const vec3 waterScatteringCoefficients = (vec3(WATER_SCATTERING_R, WATER_SCATTERING_G, WATER_SCATTERING_B) * 0.01) * SRGB_2_AP1_ALBEDO;
#else 
    const vec3 waterAbsorptionCoefficients = vec3(WATER_ABSORPTION_R, WATER_ABSORPTION_G, WATER_ABSORPTION_B) * 0.01;
    const vec3 waterScatteringCoefficients = vec3(WATER_SCATTERING_R, WATER_SCATTERING_G, WATER_SCATTERING_B) * 0.01;
#endif

vec3 waterExtinctionCoefficients = saturate(waterScatteringCoefficients + waterAbsorptionCoefficients);

#if WATER_FOG == 0
    void computeWaterFogApproximation(out vec3 scatteringOut, out vec3 transmittanceOut, vec3 startPosition, vec3 endPosition, float VdotL, vec3 directIlluminance, vec3 skyIlluminance, float skylight) {
        transmittanceOut = exp(-waterAbsorptionCoefficients * distance(startPosition, endPosition));

        scatteringOut  = skyIlluminance    * isotropicPhase * skylight;
        scatteringOut += directIlluminance * kleinNishinaPhase(VdotL, 0.5);
        scatteringOut *= waterScatteringCoefficients * (1.0 - transmittanceOut) / waterAbsorptionCoefficients;
    }
#else

    // Thanks Jessie for the help!
    void computeVolumetricWaterFog(out vec3 scatteringOut, out vec3 transmittanceOut, vec3 startPosition, vec3 endPosition, float VdotL, vec3 directIlluminance, vec3 skyIlluminance, float skylight, bool sky) {
        const float stepSize = 1.0 / WATER_FOG_STEPS;

        vec3 increment    = (endPosition - startPosition) * stepSize;
        vec3 rayPosition  = startPosition + increment * dither;
             rayPosition += cameraPosition;

        vec3 shadowStartPosition = worldToShadow(startPosition);
        vec3 shadowIncrement     = (worldToShadow(endPosition) - shadowStartPosition) * stepSize;
        vec3 shadowPosition      = shadowStartPosition + shadowIncrement * dither;

        vec3 stepTransmittance  = exp(-waterExtinctionCoefficients * length(increment));
        vec3 scatteringIntegral = waterScatteringCoefficients * (1.0 - stepTransmittance) / waterExtinctionCoefficients;

        mat2x3 scattering    = mat2x3(vec3(0.0), vec3(0.0)); 
        vec3   transmittance = vec3(1.0);

        for(int i = 0; i < WATER_FOG_STEPS; i++, rayPosition += increment, shadowPosition += shadowIncrement) {
            vec3 shadowColor = getShadowColor(distortShadowSpace(shadowPosition) * 0.5 + 0.5);

            #if CLOUDS_SHADOWS == 1 && PRIMARY_CLOUDS == 1
                shadowColor *= getCloudsShadows(rayPosition);
            #endif

            mat2x3 stepScattering = mat2x3(vec3(0.0), vec3(0.0));

            stepScattering[0] = stepTransmittance * shadowColor;
            stepScattering[1] = stepTransmittance * isotropicPhase * skylight;

            scattering[0] += stepScattering[0] * scatteringIntegral * transmittance;
            scattering[1] += stepScattering[1] * scatteringIntegral * transmittance;
            
            transmittance *= stepTransmittance;
        }
        scattering[0] *= directIlluminance;
        scattering[1] *= skyIlluminance;

        // Multiple scattering approximation provided by Jessie
        vec3 scatteringAlbedo         = saturate(waterScatteringCoefficients / waterExtinctionCoefficients);
        vec3 multipleScatteringFactor = scatteringAlbedo * 0.84;

        int phaseSampleCount = 32;
        float phaseMultiple  = 0.0;

        for(int i = 0; i < phaseSampleCount; i++) {
            phaseMultiple += cornetteShanksPhase(VdotL, 0.6 * pow(0.5, phaseSampleCount));
        }
        phaseMultiple /= phaseSampleCount;

        scatteringOut  = (scattering[0] + scattering[1]) * phaseMultiple;
        scatteringOut *= multipleScatteringFactor / (1.0 - multipleScatteringFactor);

	    if(sky) { transmittanceOut = vec3(1.0); return; }
        transmittanceOut = transmittance;
    }
#endif
