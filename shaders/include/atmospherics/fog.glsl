/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/include/atmospherics/atmosphere.glsl"

float jitter = fract(frameTimeCounter + bayer128(gl_FragCoord.xy));

float getFogDensity(vec3 position) {
    float altitude   = (position.y - FOG_ALTITUDE) * rcp(FOG_THICKNESS);
    float shapeAlter = remap(altitude, 0.0, 0.2, 0.0, 1.0) * remap(altitude, 0.9, 1.0, 1.0, 0.0);

    /*
        CREDITS (density function):
        SixSeven: https://www.curseforge.com/minecraft/customization/voyager-shader-2-0
    */
    float shapeNoise  = FBM(position * 0.02, 3, 4.0);
          shapeNoise  = shapeNoise * shapeAlter * 0.4 - (2.0 * shapeAlter * altitude * 0.5 + 0.5);
          shapeNoise *= exp(-max0(position.y - FOG_ALTITUDE) * 0.2);
        
    return clamp01(shapeNoise) * mix(0.1, 1.0, max(rainStrength, wetness));
}

#if AIR_FOG == 0
    void groundFog(inout vec3 color, vec3 scenePos, vec3 directIlluminance, vec3 skyIlluminance, float skyLight, bool sky) {
        float airmass     = getFogDensity(scenePos) * length(scenePos);
        vec3 opticalDepth = (atmosExtinctionCoeff[0] + atmosExtinctionCoeff[1] + atmosExtinctionCoeff[2]) * airmass;

        vec3 transmittance       = exp(-opticalDepth);
        vec3 transmittedFraction = clamp01((transmittance - 1.0) / -opticalDepth);

        float VdotL = dot(normalize(scenePos), shadowLightVector);
        vec2  phase = vec2(rayleighPhase(VdotL), kleinNishinaPhase(VdotL, anisotropyFactor));

	    vec3 scattering  = atmosScatteringCoeff * vec2(airmass * phase)          * (directIlluminance * skyLight);
	         scattering += atmosScatteringCoeff * vec2(airmass * isotropicPhase) * (skyIlluminance    * skyLight);
	         scattering *= transmittedFraction;

        color = color * transmittance + scattering;
    }

#else

    float getFogPhase(float cosTheta) {
        float forwardsLobe  = cornetteShanksPhase(cosTheta, fogForwardsLobe);
        float backwardsLobe = cornetteShanksPhase(cosTheta,-fogBackardsLobe);
        float forwardsPeak  = cornetteShanksPhase(cosTheta, fogForwardsPeak);

        return mix(mix(forwardsLobe, backwardsLobe, fogBackScatter), forwardsPeak, fogPeakWeight);
    }

    /*
    float getFogTransmittance(vec3 rayOrigin, vec3 lightDir) {
        const float stepLength = 1.0 / VL_TRANSMITTANCE_STEPS;
        vec3 increment   = lightDir * stepLength;
        vec3 rayPos      = rayOrigin + increment * 0.5;

        float accumAirmass = 0.0;
        for(int i = 0; i < VL_TRANSMITTANCE_STEPS; i++, rayPos += increment) {
            accumAirmass += getFogDensity(rayPos) * stepLength;
        }
        return exp(-fogExtinctionCoeff * accumAirmass);
    }
    */

    void volumetricFog(inout vec3 color, vec3 startPos, vec3 endPos, float VdotL, vec3 directIlluminance, vec3 skyIlluminance, float skyLight) {
        const float stepLength = 1.0 / VL_SCATTERING_STEPS;
        vec3 increment = (endPos - startPos) * stepLength;
        vec3 rayPos    = startPos + increment * jitter;
             rayPos   += cameraPosition;

        vec3 shadowStartPos  = worldToShadow(startPos);
        vec3 shadowIncrement = (worldToShadow(endPos) - shadowStartPos) * stepLength;
        vec3 shadowPos       = shadowStartPos + shadowIncrement * jitter;

        float rayLength = length(increment);
        float phase     = getFogPhase(VdotL);

        mat2x3 scattering   = mat2x3(vec3(0.0), vec3(0.0)); 
        float transmittance = 1.0, depthWeight = 0.0, depthSum = 0.0;

        for(int i = 0; i < VL_SCATTERING_STEPS; i++, rayPos += increment, shadowPos += shadowIncrement) {
            float density      = getFogDensity(rayPos);
            float airmass      = density * rayLength;
            float opticalDepth = fogExtinctionCoeff    * airmass;

            depthSum    += distance(startPos, rayPos) * density; 
            depthWeight += density;

            float stepTransmittance = exp(-opticalDepth);
            float visibleScattering = transmittance * clamp01((stepTransmittance - 1.0) / -opticalDepth);

            float stepScatteringDirect   = fogScatteringCoeff * airmass * phase          * visibleScattering;
            float stepScatteringIndirect = fogScatteringCoeff * airmass * isotropicPhase * visibleScattering;

            vec3 shadowColor = getShadowColor(distortShadowSpace(shadowPos) * 0.5 + 0.5);

            scattering[0] += stepScatteringDirect * shadowColor;
            scattering[1] += stepScatteringIndirect;
            transmittance *= stepTransmittance;
        }

        float distToFog = depthSum / depthWeight;

        scattering[0] *= directIlluminance;
        scattering[1] *= skyIlluminance * skyLight;

        color += mix(vec3(0.0), scattering[0] + scattering[1], quintic(0.0, 1.0, pow(exp(-1e-3 * distToFog), 1.2)));
    }
#endif

#if TONEMAP == 0
    const vec3 waterAbsorptionCoeff = (vec3(WATER_ABSORPTION_R, WATER_ABSORPTION_G, WATER_ABSORPTION_B) * 0.01) * sRGB_2_AP1_ALBEDO;
    const vec3 waterScatteringCoeff = (vec3(WATER_SCATTERING_R, WATER_SCATTERING_G, WATER_SCATTERING_B) * 0.01) * sRGB_2_AP1_ALBEDO;
#else 
    const vec3 waterAbsorptionCoeff = vec3(WATER_ABSORPTION_R, WATER_ABSORPTION_G, WATER_ABSORPTION_B) * 0.01;
    const vec3 waterScatteringCoeff = vec3(WATER_SCATTERING_R, WATER_SCATTERING_G, WATER_SCATTERING_B) * 0.01;
#endif

const vec3 waterExtinctionCoeff = waterAbsorptionCoeff + waterScatteringCoeff;
const int phaseMultiSamples = 8;

#if WATER_FOG == 0
    // Sources: ShaderLabs, Spectrum - Zombye
    void waterFog(inout vec3 color, vec3 startPos, vec3 endPos, float VdotL, vec3 directIlluminance, vec3 skyIlluminance, float skyLight) {
        vec3 transmittance = exp(-waterAbsorptionCoeff * distance(startPos, endPos));

        vec3 scattering  = skyIlluminance * isotropicPhase * skyLight;
             scattering += directIlluminance * kleinNishinaPhase(VdotL, 0.5) * skyLight;
             scattering *= waterScatteringCoeff - waterScatteringCoeff * transmittance;

        color = color * transmittance + scattering;
    }
    
#else

    // Thanks Jessie#7257 for the help!
    void volumetricWaterFog(inout vec3 color, vec3 startPos, vec3 endPos, float VdotL, vec3 directIlluminance, vec3 skyIlluminance, float skyLight, bool sky) {
        const float stepLength = 1.0 / WATER_FOG_STEPS;
        vec3 increment = (endPos - startPos) * stepLength;
        vec3 rayPos    = startPos + increment * jitter;
             rayPos   += cameraPosition;

        vec3 shadowStartPos  = worldToShadow(startPos);
        vec3 shadowIncrement = (worldToShadow(endPos) - shadowStartPos) * stepLength;
        vec3 shadowPos       = shadowStartPos + shadowIncrement * jitter;

        float rayLength = length(increment);

        vec3 opticalDepth       = waterExtinctionCoeff * rayLength;
        vec3 stepTransmittance  = exp(-opticalDepth);
        vec3 scatteringIntegral = (1.0 - stepTransmittance) / waterExtinctionCoeff;

        mat2x3 scatteringMat = mat2x3(vec3(0.0), vec3(0.0)); vec3 transmittance = vec3(1.0);

        for(int i = 0; i < WATER_FOG_STEPS; i++, rayPos += increment, shadowPos += shadowIncrement) {
            vec3 shadowColor = getShadowColor(distortShadowSpace(shadowPos) * 0.5 + 0.5);

            for(int n = 0; n < 3; n++) {
                float phase = mix(kleinNishinaPhase(VdotL, 0.6), isotropicPhase, float(n) * rcp(3.0));
                float aN = pow(0.6, n), bN = pow(0.4, n);

                mat2x3 stepScatteringMat = mat2x3(vec3(0.0), vec3(0.0));
                stepScatteringMat[0] = exp(-opticalDepth * bN) * shadowColor * phase          * waterScatteringCoeff * scatteringIntegral;
                stepScatteringMat[1] = exp(-opticalDepth * bN) * skyLight    * isotropicPhase * waterScatteringCoeff * scatteringIntegral;

                scatteringMat[0] += stepScatteringMat[0] * transmittance * aN;
                scatteringMat[1] += stepScatteringMat[1] * transmittance * aN;
            }
            transmittance *= stepTransmittance;
        }

        scatteringMat[0] *= directIlluminance;
        scatteringMat[1] *= skyIlluminance;

        // Multiple scattering approximation provided by Zombye#7365
        /*
        vec3 scatteringAlbedo     = clamp01(waterScatteringCoeff / waterExtinctionCoeff);
        vec3 multScatteringFactor = scatteringAlbedo * 0.84;

        float phaseMulti = 0.0;
        for(int i = 0; i < phaseMultiSamples; i++) {
            phaseMulti += cornetteShanksPhase(VdotL, 0.6 * pow(0.5, phaseMultiSamples));
        }
        phaseMulti /= phaseMultiSamples;

        vec3 multipleScattering  = directScattering * directIlluminance * phaseMulti;
             multipleScattering += indirectScattering * isotropicPhase;
             multipleScattering *= multScatteringFactor / (1.0 - multScatteringFactor);
        */

        vec3 scattering = scatteringMat[0] + scatteringMat[1];
        if(sky) transmittance = vec3(0.0);
    
        color = color * transmittance + scattering;
    }
#endif
