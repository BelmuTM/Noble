/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/include/atmospherics/atmosphere.glsl"

void volumetricGroundFog(inout vec3 color, vec3 viewPos, float skyLight) {
    vec3 scenePos = viewToScene(viewPos);

    float airmass     = isSky(texCoords) ? far : length(scenePos) * pow2(quintic(0.0, 1.0, skyLight));
          airmass    *= RAIN_FOG_DENSITY * rainStrength;
    vec3 opticalDepth = (kExtinction[0] + kExtinction[1] + kExtinction[2]) * airmass;

    vec3 transmittance       = exp(-opticalDepth);
    vec3 transmittedFraction = clamp01((transmittance - 1.0) / -opticalDepth);

    float VdotL     = dot(normalize(scenePos), dirShadowLight);
    vec2 phase      = vec2(rayleighPhase(VdotL), cornetteShanksPhase(VdotL, anisoFactor));
    vec3 scattering = kScattering * (airmass * phase) * (worldTime <= 12750 ? sunIlluminance : moonIlluminance);

    color = color * transmittance + (scattering * transmittedFraction);
}

// Thanks Jessie, LVutner and SixthSurge for the help!

vec3 vlTransmittance(vec3 rayOrigin, vec3 lightDir) {
    float stepLength = 1.0 / TRANSMITTANCE_STEPS;
    vec3 increment  = lightDir * stepLength;
    vec3 rayPos     = rayOrigin + increment * 0.5;

    vec3 accumAirmass = vec3(0.0);
    for(int j = 0; j < TRANSMITTANCE_STEPS; j++, rayPos += increment) {
        accumAirmass += vlDensities(rayPos.y) * stepLength;
    }
    return exp(-kExtinction * accumAirmass);
}

vec3 volumetricLighting(vec3 viewPos) {
    vec3 startPos = gbufferModelViewInverse[3].xyz;
    vec3 endPos   = viewToScene(viewPos);

    float jitter = fract(frameTimeCounter + bayer16(gl_FragCoord.xy));

    vec3 increment = (endPos - startPos) / float(VL_STEPS);
    vec3 rayPos    = startPos + increment * jitter;

    vec3 shadowStartPos  = worldToShadow(startPos);
    vec3 shadowIncrement = (worldToShadow(endPos) - shadowStartPos) / float(VL_STEPS);
    vec3 shadowPos       = shadowStartPos + shadowIncrement * jitter;

    float VdotL = dot(normalize(endPos), dirShadowLight);
    vec2 phase  = vec2(rayleighPhase(VdotL), cornetteShanksPhase(VdotL, anisoFactor));

    vec3 scattering  = vec3(0.0), transmittance = vec3(1.0);
    float stepLength = length(increment);

    for(int i = 0; i < VL_STEPS; i++, rayPos += increment, shadowPos += shadowIncrement) {
        vec3 airmass      = vlDensities(rayPos.y) * stepLength;
        vec3 opticalDepth = kExtinction * airmass;

        vec3 stepTransmittance = exp(-opticalDepth);
        vec3 visibleScattering = transmittance * clamp01((stepTransmittance - 1.0) / -opticalDepth);
        vec3 stepScattering    = kScattering * vec2(airmass.xy * phase.xy) * visibleScattering;

        vec3 sampleColor = getShadowColor(distortShadowSpace(shadowPos) * 0.5 + 0.5, 0.0);

        scattering    += stepScattering * vlTransmittance(rayPos, dirShadowLight) * sampleColor;
        transmittance *= stepTransmittance;
    }
    
    vec3 directIllum = sampleDirectIlluminance();
    scattering     *= mix(directIllum, vec3(luminance(directIllum)), rainStrength);

    return max0(scattering);
}

vec3 absorptionCoeff = sRGBToLinear(vec3(WATER_ABSORPTION_R, WATER_ABSORPTION_G, WATER_ABSORPTION_B) / 100.0);
vec3 scatteringCoeff = sRGBToLinear(vec3(WATER_SCATTERING_R, WATER_SCATTERING_G, WATER_SCATTERING_B) / 100.0) * WATER_DENSITY;
vec3 extinctionCoeff = absorptionCoeff + scatteringCoeff;

// Sources: ShaderLabs, Spectrum - Zombye
void waterFog(inout vec3 color, float dist, float VdotL, vec3 skyIlluminance, float skyLight) {
    vec3 transmittance = exp(-absorptionCoeff * WATER_DENSITY * dist);

    vec3 scattering  = skyIlluminance * isotropicPhase * pow2(quintic(0.0, 1.0, skyLight));
         scattering += (worldTime <= 12750 ? sunIlluminance : moonIlluminance) * cornetteShanksPhase(VdotL, 0.5);
         scattering  = scattering * (scatteringCoeff - scatteringCoeff * transmittance);

    color = color * transmittance + scattering;
}

// Thanks Jessie#7257 for the help!
void volumetricWaterFog(inout vec3 color, vec3 startPos, vec3 endPos, vec3 waterDir, vec3 skyIlluminance, float skyLight) {
    float jitter = fract(frameTimeCounter + bayer16(gl_FragCoord.xy));

    vec3 increment = (endPos - startPos) / float(WATER_FOG_STEPS);
    vec3 rayPos    = startPos + increment * jitter;

    vec3 shadowStartPos  = worldToShadow(startPos);
    vec3 shadowIncrement = (worldToShadow(endPos) - shadowStartPos) / float(WATER_FOG_STEPS);
    vec3 shadowPos       = shadowStartPos + shadowIncrement * jitter;

    float rayLength = (isSky(texCoords) ? far : distance(startPos, endPos)) / float(WATER_FOG_STEPS);
    float VdotL     = dot(waterDir, dirShadowLight);

    vec3 opticalDepth            = extinctionCoeff * WATER_DENSITY * rayLength;
    vec3 stepTransmittance       = exp(-opticalDepth);
    vec3 stepTransmittedFraction = clamp01((stepTransmittance - 1.0) / -opticalDepth);

    vec3 directScatter = vec3(0.0), indirectScatter = vec3(0.0), transmittance = vec3(1.0);

    for(int i = 0; i < WATER_FOG_STEPS; i++, rayPos += increment, shadowPos += shadowIncrement) {
        vec3 sampleColor          = getShadowColor(distortShadowSpace(shadowPos) * 0.5 + 0.5, 0.0);
        vec3 sampledTransmittance = stepTransmittance * stepTransmittedFraction;

        directScatter   += transmittance * sampleColor;
        indirectScatter += transmittance;
        transmittance   *= stepTransmittance;
    }

    vec3 scattering = vec3(0.0);
    scattering += directScatter   * sampleDirectIlluminance() * cornetteShanksPhase(VdotL, 0.5);
    scattering *= scatteringCoeff * (1.0 - stepTransmittance) / extinctionCoeff;

    // Multiple scattering approximation provided by Jessie#7257
    vec3 scatteringAlbedo     = clamp01(scatteringCoeff / extinctionCoeff);
    vec3 multScatteringFactor = scatteringAlbedo * 0.84;

    float phaseMulti = 0.0;
    int samples      = 16;
    for(int i = 0; i < samples; i++) {
        phaseMulti += cornetteShanksPhase(VdotL, 0.6 * pow(0.5, samples));
    }
    phaseMulti /= samples;

    vec3 scatteringMultiple  = scattering * phaseMulti;
         scatteringMultiple += indirectScatter * pow2(quintic(0.0, 1.0, skyLight)) * phaseMulti;
         scatteringMultiple *= multScatteringFactor / (1.0 - multScatteringFactor);

    color = color * transmittance + (scattering + scatteringMultiple);
}
