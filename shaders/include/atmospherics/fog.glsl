/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/include/atmospherics/atmosphere.glsl"

vec3 groundFog(vec3 viewPos, vec3 background, vec3 fogColor, float fogCoef, float d) {
    float dist    = length(transMAD3(gbufferModelViewInverse, viewPos));
    return mix(vec3(0.0), fogColor, dist * d * fogCoef);
}

// Thanks Jessie, LVutner and SixthSurge for the help!

vec3 vlTransmittance(vec3 rayOrigin, vec3 lightDir) {
    float rayLength = 1.0 / TRANSMITTANCE_STEPS;
    vec3 increment  = lightDir * rayLength;
    vec3 rayPos     = rayOrigin + increment * 0.5;

    vec3 accumAirmass = vec3(0.0);
    for(int j = 0; j < TRANSMITTANCE_STEPS; j++, rayPos += increment) {
        accumAirmass += vlDensities(rayPos.y) * rayLength;
    }
    return exp(-kExtinction * accumAirmass);
}

vec3 volumetricLighting(vec3 viewPos) {
    vec3 startPos = gbufferModelViewInverse[3].xyz;
    vec3 endPos   = transMAD3(gbufferModelViewInverse, viewPos);

    float jitter = fract(frameTimeCounter + bayer16(gl_FragCoord.xy));

    vec3 increment = (endPos - startPos) / float(VL_STEPS);
    vec3 rayPos    = startPos + increment * jitter;
    vec3 lightDir  = worldTime <= 12750 ? playerSunDir : playerMoonDir;

    float VdotL = dot(normalize(endPos), lightDir);
    vec2 phase  = vec2(rayleighPhase(VdotL), cornetteShanksPhase(VdotL, anisoFactor));

    vec3 scattering = vec3(0.0), transmittance = vec3(1.0);
    float rayLength = length(increment);

    for(int i = 0; i < VL_STEPS; i++, rayPos += increment) {
        vec3 sampleColor = sampleShadowColor(worldToShadowClip(rayPos) * 0.5 + 0.5);

        vec3 airmass      = vlDensities(rayPos.y) * rayLength;
        vec3 opticalDepth = kExtinction * airmass;

        vec3 stepTransmittance = exp(-opticalDepth);
        vec3 visibleScattering = transmittance * clamp01((stepTransmittance - 1.0) / -opticalDepth);
        vec3 stepScattering    = kScattering * vec2(airmass.xy * phase.xy) * visibleScattering;

        scattering    += stepScattering * vlTransmittance(rayPos, lightDir) * sampleColor;
        transmittance *= stepTransmittance;
    }
    
    vec3 totalIllum = shadowLightTransmittance();
    scattering     *= mix(totalIllum, vec3(luminance(totalIllum)), rainStrength);

    return max0(scattering);
}

vec3 absorptionCoeff = RGBtoLinear(vec3(WATER_ABSORPTION_R, WATER_ABSORPTION_G, WATER_ABSORPTION_B) / 255.0);
vec3 scatteringCoeff = RGBtoLinear(vec3(WATER_SCATTERING_R, WATER_SCATTERING_G, WATER_SCATTERING_B) / 255.0);

// Sources: ShaderLabs, Spectrum - Zombye
void waterFog(inout vec3 color, float dist, float VdotL, vec3 skyIlluminance) {
    vec3 transmittance = exp(-absorptionCoeff * WATER_DENSITY * dist);

    vec3 scattering  = skyIlluminance * isotropicPhase;
         scattering += illuminanceShadowLight * cornetteShanksPhase(VdotL, 0.5);
         scattering  = scattering * (scatteringCoeff - scatteringCoeff * transmittance);

    color = color * transmittance + scattering;
}

void volumetricWaterFog(inout vec3 color, vec3 startPos, vec3 endPos, vec3 waterDir) {
    float jitter = fract(frameTimeCounter + bayer16(gl_FragCoord.xy));

    vec3 increment = (endPos - startPos) / float(WATER_FOG_STEPS);
    vec3 rayPos    = startPos + increment * jitter;
    vec3 lightDir  = worldTime <= 12750 ? playerSunDir : playerMoonDir;

    vec3 scattering = vec3(0.0), transmittance = vec3(1.0);
    float rayLength = distance(startPos, endPos) / float(WATER_FOG_STEPS);

    vec3 opticalDepth            = absorptionCoeff * WATER_DENSITY * rayLength;
    vec3 stepTransmittance       = exp(-opticalDepth);
    vec3 stepTransmittedFraction = clamp01((stepTransmittance - 1.0) / -opticalDepth);

    for(int i = 0; i < WATER_FOG_STEPS; i++, rayPos += increment) {
        vec3 sampleColor = sampleShadowColor(worldToShadowClip(rayPos) * 0.5 + 0.5);

        scattering    += (stepTransmittance * stepTransmittedFraction) * sampleColor;
        transmittance *= stepTransmittance;
    }

    float VdotL = dot(waterDir, lightDir);
    scattering *= shadowLightTransmittance() * cornetteShanksPhase(VdotL, 0.5);
    scattering *= scatteringCoeff * opticalDepth;

    color = color * transmittance + max0(scattering);
}
