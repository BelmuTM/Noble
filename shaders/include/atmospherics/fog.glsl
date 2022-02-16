/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/include/atmospherics/atmosphere.glsl"

void volumetricGroundFog(inout vec3 color, vec3 viewPos, float skyLight) {
    vec3 scenePos = transMAD3(gbufferModelViewInverse, viewPos);

    float airmass     = isSky(texCoords) ? far : length(scenePos) * pow2(quintic(0.0, 1.0, skyLight));
          airmass    *= RAIN_FOG_DENSITY * rainStrength;
    vec3 opticalDepth = (kExtinction[0] + kExtinction[1] + kExtinction[2]) * airmass;

    vec3 transmittance       = exp(-opticalDepth);
    vec3 transmittedFraction = clamp01((transmittance - 1.0) / -opticalDepth);

    float VdotL     = dot(normalize(scenePos), dirShadowLight);
    vec2 phase      = vec2(rayleighPhase(VdotL), cornetteShanksPhase(VdotL, anisoFactor));
    vec3 scattering = kScattering * (airmass * phase) * illuminanceShadowLight;

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
    vec3 endPos   = transMAD3(gbufferModelViewInverse, viewPos);

    float jitter = fract(frameTimeCounter + bayer16(gl_FragCoord.xy));

    vec3 increment = (endPos - startPos) / float(VL_STEPS);
    vec3 rayPos    = startPos + increment * jitter;

    float VdotL = dot(normalize(endPos), dirShadowLight);
    vec2 phase  = vec2(rayleighPhase(VdotL), cornetteShanksPhase(VdotL, anisoFactor));

    vec3 scattering = vec3(0.0), transmittance = vec3(1.0);
    float stepLength = length(increment);

    for(int i = 0; i < VL_STEPS; i++, rayPos += increment) {
        vec3 sampleColor = sampleShadowColor(worldToShadowClip(rayPos) * 0.5 + 0.5);

        vec3 airmass      = vlDensities(rayPos.y) * stepLength;
        vec3 opticalDepth = kExtinction * airmass;

        vec3 stepTransmittance = exp(-opticalDepth);
        vec3 visibleScattering = transmittance * clamp01((stepTransmittance - 1.0) / -opticalDepth);
        vec3 stepScattering    = kScattering * vec2(airmass.xy * phase.xy) * visibleScattering;

        scattering    += stepScattering * vlTransmittance(rayPos, dirShadowLight) * sampleColor;
        transmittance *= stepTransmittance;
    }
    
    vec3 totalIllum = shadowLightTransmittance();
    scattering     *= mix(totalIllum, vec3(luminance(totalIllum)), rainStrength);

    return max0(scattering);
}

vec3 absorptionCoeff = RGBtoLinear(vec3(WATER_ABSORPTION_R, WATER_ABSORPTION_G, WATER_ABSORPTION_B) / 100.0);
vec3 scatteringCoeff = RGBtoLinear(vec3(WATER_SCATTERING_R, WATER_SCATTERING_G, WATER_SCATTERING_B) / 100.0) * WATER_DENSITY;

// Sources: ShaderLabs, Spectrum - Zombye
void waterFog(inout vec3 color, float dist, float VdotL, vec3 skyIlluminance, float skyLight) {
    vec3 transmittance = exp(-absorptionCoeff * WATER_DENSITY * dist);

    vec3 scattering  = skyIlluminance * isotropicPhase * pow2(quintic(0.0, 1.0, skyLight));
         scattering += illuminanceShadowLight * cornetteShanksPhase(VdotL, 0.5);
         scattering  = scattering * (scatteringCoeff - scatteringCoeff * transmittance);

    color = color * transmittance + scattering;
}

void volumetricWaterFog(inout vec3 color, vec3 startPos, vec3 endPos, vec3 waterDir, vec3 skyIlluminance, float skyLight) {
    float jitter = fract(frameTimeCounter + bayer16(gl_FragCoord.xy));

    vec3 increment = (endPos - startPos) / float(WATER_FOG_STEPS);
    vec3 rayPos    = startPos + increment * jitter;

    vec3 shadowStartPos  = worldToShadowClip(startPos);
    vec3 shadowIncrement = (worldToShadowClip(endPos) - shadowStartPos) / float(WATER_FOG_STEPS);
    vec3 shadowPos       = shadowStartPos + shadowIncrement * jitter;

    float rayLength = (isSky(texCoords) ? far : distance(startPos, endPos)) / float(WATER_FOG_STEPS);
    float VdotL     = dot(waterDir, dirShadowLight);

    vec3 opticalDepth            = absorptionCoeff * WATER_DENSITY * rayLength;
    vec3 stepTransmittance       = exp(-opticalDepth);
    vec3 stepTransmittedFraction = clamp01((stepTransmittance - 1.0) / -opticalDepth);

    vec3 directScatter = vec3(0.0), indirectScatter = vec3(0.0), transmittance = vec3(1.0);

    for(int i = 0; i < WATER_FOG_STEPS; i++, rayPos += increment, shadowPos += shadowIncrement) {
        vec3 sampledTransmittance = stepTransmittance * stepTransmittedFraction;

        directScatter   += sampledTransmittance * sampleShadowColor(shadowPos);
        indirectScatter += sampledTransmittance;
        transmittance   *= stepTransmittance;
    }

    vec3 scattering = vec3(0.0);
    scattering += directScatter   * shadowLightTransmittance() * cornetteShanksPhase(VdotL, 0.5);
    scattering += indirectScatter * skyIlluminance * isotropicPhase * pow2(quintic(0.0, 1.0, skyLight));
    scattering *= scatteringCoeff * opticalDepth;

    color = color * transmittance + scattering;
}
