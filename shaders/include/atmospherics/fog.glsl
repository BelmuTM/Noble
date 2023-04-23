/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/include/atmospherics/atmosphere.glsl"

float dither = fract(frameTimeCounter + bayer256(gl_FragCoord.xy));

float getFogPhase(float cosTheta) {
    float forwardsLobe  = cornetteShanksPhase(cosTheta, fogForwardsLobe);
    float backwardsLobe = cornetteShanksPhase(cosTheta,-fogBackardsLobe);
    float forwardsPeak  = cornetteShanksPhase(cosTheta, fogForwardsPeak);

    return mix(mix(forwardsLobe, backwardsLobe, fogBackScatter), forwardsPeak, fogPeakWeight);
}

#if AIR_FOG == 0
    void fog(inout vec3 color, vec3 viewPosition, float VdotL, vec3 directIlluminance, vec3 skyIlluminance, float skyLight, bool sky) {
        float airmass       = length(viewPosition) * 0.01 * (FOG_DENSITY * 10.0);
        float transmittance = exp(-fogExtinctionCoefficient * airmass);

        vec3 scattering  = skyIlluminance    * isotropicPhase     * skyLight;
             scattering += directIlluminance * getFogPhase(VdotL) * skyLight;
             scattering *= fogScatteringCoefficient * ((1.0 - transmittance) / fogExtinctionCoefficient);

        color = color * transmittance + scattering;
    }

#else

    float getFogDensity(vec3 position) {
        float altitude   = (position.y - FOG_ALTITUDE) * rcp(FOG_THICKNESS);
        float shapeAlter = remap(altitude, 0.0, 0.2, 0.0, 1.0) * remap(altitude, 0.9, 1.0, 1.0, 0.0);

        /*
            CREDITS (density function):
            SixSeven: https://www.curseforge.com/minecraft/customization/voyager-shader-2-0
        */
        float shapeNoise  = FBM(position * 0.03, 3, 2.0);
              shapeNoise  = shapeNoise * shapeAlter * 0.4 - (2.0 * shapeAlter * altitude * 0.5 + 0.5);
              shapeNoise *= exp(-max0(position.y - FOG_ALTITUDE) * 0.2);
        
        return saturate(shapeNoise) * mix(FOG_DENSITY, 1.0, wetness);
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

    void volumetricFog(inout vec3 color, vec3 startPos, vec3 endPos, vec3 viewPosition, float VdotL, vec3 directIlluminance, vec3 skyIlluminance, float skyLight) {
        const float stepSize = 1.0 / VL_SCATTERING_STEPS;
        vec3 increment    = (endPos - startPos) * stepSize;
        vec3 rayPosition  = startPos + increment * dither;
             rayPosition += cameraPosition;

        vec3 shadowStartPos  = worldToShadow(startPos);
        vec3 shadowIncrement = (worldToShadow(endPos) - shadowStartPos) * stepSize;
        vec3 shadowPos       = shadowStartPos + shadowIncrement * dither;

        float rayLength = length(increment);
        float phase     = getFogPhase(VdotL);

        float perspective = quintic(0.0, 1.0, exp2(-5e-4 * length(viewPosition)));

        mat2x3 scattering   = mat2x3(vec3(0.0), vec3(0.0)); 
        float transmittance = 1.0;

        for(int i = 0; i < VL_SCATTERING_STEPS; i++, rayPosition += increment, shadowPos += shadowIncrement) {
            float density      = getFogDensity(rayPosition);
            float airmass      = density * rayLength;
            float opticalDepth = fogExtinctionCoefficient * airmass;

            float stepTransmittance = exp(-opticalDepth);
            float visibleScattering = transmittance * saturate((stepTransmittance - 1.0) / -opticalDepth);

            float stepScatteringDirect   = fogScatteringCoefficient * airmass * phase          * visibleScattering;
            float stepScatteringIndirect = fogScatteringCoefficient * airmass * isotropicPhase * visibleScattering;

            vec3 shadowColor = getShadowColor(distortShadowSpace(shadowPos) * 0.5 + 0.5);

            scattering[0] += stepScatteringDirect * shadowColor;
            scattering[1] += stepScatteringIndirect;
            transmittance *= perspective * stepTransmittance;
        }
        scattering[0] *= directIlluminance;
        scattering[1] *= skyIlluminance * skyLight;

        color += scattering[0] + scattering[1];
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

    void waterFog(inout vec3 color, vec3 startPos, vec3 endPos, float VdotL, vec3 directIlluminance, vec3 skyIlluminance, float skyLight) {
        vec3 transmittance = exp(-waterAbsorptionCoefficients * distance(startPos, endPos));

        vec3 scattering  = skyIlluminance    * isotropicPhase * skyLight;
             scattering += directIlluminance * kleinNishinaPhase(VdotL, 0.5);
             scattering *= waterScatteringCoefficients * (1.0 - transmittance) / waterAbsorptionCoefficients;

        color = color * transmittance + scattering;
    }
#else

    // Thanks Jessie for the help!
    void volumetricWaterFog(inout vec3 color, vec3 startPos, vec3 endPos, float VdotL, vec3 directIlluminance, vec3 skyIlluminance, float skyLight, bool sky) {
        const float stepSize = 1.0 / WATER_FOG_STEPS;
        vec3 increment    = (endPos - startPos) * stepSize;
        vec3 rayPosition  = startPos + increment * dither;
             rayPosition += cameraPosition;

        vec3 shadowStartPos  = worldToShadow(startPos);
        vec3 shadowIncrement = (worldToShadow(endPos) - shadowStartPos) * stepSize;
        vec3 shadowPos       = shadowStartPos + shadowIncrement * dither;

        vec3 stepTransmittance  = exp(-waterExtinctionCoefficients * length(increment));
        vec3 scatteringIntegral = waterScatteringCoefficients * (1.0 - stepTransmittance) / waterExtinctionCoefficients;

        mat2x3 scattering  = mat2x3(vec3(0.0), vec3(0.0)); 
        vec3 transmittance = vec3(1.0);

        for(int i = 0; i < WATER_FOG_STEPS; i++, rayPosition += increment, shadowPos += shadowIncrement) {
            vec3 shadowColor = getShadowColor(distortShadowSpace(shadowPos) * 0.5 + 0.5);

            mat2x3 stepScattering = mat2x3(vec3(0.0), vec3(0.0));

            stepScattering[0] = stepTransmittance * shadowColor;
            stepScattering[1] = stepTransmittance * isotropicPhase;

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

        vec3 scatteringMultiple  = scattering[0] * phaseMultiple;
             scatteringMultiple += scattering[1] * phaseMultiple;
             scatteringMultiple *= multipleScatteringFactor / (1.0 - multipleScatteringFactor);

	    if(sky) transmittance = vec3(1.0);
    
        color = color * transmittance + scatteringMultiple;
    }
#endif
