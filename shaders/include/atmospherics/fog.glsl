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
    float rayLength = 1.34; // I DONT KNOW
    vec3 increment  = lightDir * rayLength;
    vec3 rayPos     = rayOrigin + increment * 0.5;

    vec3 transmittance = vec3(1.0);
    for(int j = 0; j < TRANSMITTANCE_STEPS; j++, rayPos += increment) {
        vec3 density   = vec3(densities(rayPos.y).xy, 0.0);
        transmittance *= exp(-kExtinction * density * rayLength);
    }
    return transmittance;
}

vec3 volumetricFog(vec3 viewPos) {
    vec3 startPos   = gbufferModelViewInverse[3].xyz;
    vec3 endPos     = mat3(gbufferModelViewInverse) * viewPos;
    float rayLength = distance(startPos, endPos) / float(VL_STEPS);

    float jitter = fract(frameTimeCounter + bayer16(gl_FragCoord.xy));
    vec3 rayDir  = (normalize(endPos - startPos) * rayLength) * jitter;

    vec3 increment = rayDir * rayLength;
    vec3 rayPos    = startPos + increment;

    vec3 lightDir; vec3 illuminance; 
    if(worldTime <= 12750) {
        lightDir    = playerSunDir;
        illuminance = sunIlluminance;
    } else {
        lightDir    = playerMoonDir;
        illuminance = moonIlluminance;
    }

    float VdotL = dot(normalize(endPos + startPos), lightDir);
    vec2 phase  = vec2(rayleighPhase(VdotL), cornetteShanksPhase(VdotL, anisoFactor));

    vec3 scattering  = vec3(0.0), transmittance = vec3(1.0);

    for(int i = 0; i < VL_STEPS; i++, rayPos += increment) {
        vec3 sampleColor = sampleShadowColor(viewPos, viewToShadowClip(gbufferModelView * vec4(rayPos, 1.0)) * 0.5 + 0.5);

        vec3 airmass      = densities(rayPos.y) * rayLength;
        vec3 opticalDepth = kExtinction * airmass;

        vec3 stepTransmittance = exp(-opticalDepth);
        vec3 visibleScattering = transmittance * clamp01((stepTransmittance - 1.0) / -opticalDepth);
        vec3 stepScattering    = kScattering * (airmass.xy * phase.xy) * visibleScattering;

        scattering    += stepScattering * vlTransmittance(rayPos.xyz, lightDir) * sampleColor * illuminance;
        transmittance *= stepTransmittance;
    }
    return max0(scattering);
}

// Sources: ShaderLabs, Spectrum - Zombye
void waterFog(inout vec3 color, float dist, float VdotL, vec3 skyIlluminance) {
    vec3 absorptionCoeff = RGBtoLinear(vec3(WATER_ABSORPTION_R, WATER_ABSORPTION_G, WATER_ABSORPTION_B) / 255.0);
    vec3 scatteringCoeff = RGBtoLinear(vec3(WATER_SCATTERING_R, WATER_SCATTERING_G, WATER_SCATTERING_B) / 255.0);

    vec3 transmittance = exp(-absorptionCoeff * WATER_DENSITY * dist);

    vec3 scattering  = skyIlluminance * isotropicPhase;
         scattering += illuminanceShadowLight * cornetteShanksPhase(VdotL, 0.5);
         scattering  = scattering * (scatteringCoeff - scatteringCoeff * transmittance);

    color = color * transmittance + scattering;
}
