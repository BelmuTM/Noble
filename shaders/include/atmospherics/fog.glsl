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
    float rayLength = (25.0 / TRANSMITTANCE_STEPS) / abs(VL_STEPS);
    vec3 increment  = lightDir * rayLength;
    vec3 rayPos     = rayOrigin + increment * 0.5;

    vec3 transmittance = vec3(0.0);
    for(int j = 0; j < TRANSMITTANCE_STEPS; j++) {
        vec2 density   = densities(rayPos.y).xy;
        transmittance *= exp(-kExtinction * vec3(density, 0.0) * rayLength);
        rayPos        += increment;
    }
    return transmittance;
}

vec3 volumetricFog(vec3 viewPos) {
    vec4 startPos   = gbufferModelViewInverse * vec4(0.0, 0.0, 0.0, 1.0);
    vec4 endPos     = gbufferModelViewInverse * vec4(viewPos, 1.0);
    float rayLength = distance(startPos, endPos) / float(VL_STEPS);

    float jitter = fract(frameTimeCounter + bayer16(gl_FragCoord.xy));
    vec4 rayDir  = (normalize(endPos - startPos) * rayLength) * jitter;

    vec4 increment = rayDir * rayLength;
    vec4 rayPos    = startPos + increment;

    float VdotL = dot(normalize(endPos + startPos).xyz, worldTime <= 12750 ? playerSunDir : playerMoonDir);
    vec2 phase  = vec2(rayleighPhase(VdotL), cornetteShanksPhase(VdotL, 0.5));

    vec3 scattering  = vec3(0.0), transmittance = vec3(1.0);
    vec3 illuminance = worldTime <= 12750 ? sunIlluminance : moonIlluminance;

    for(int i = 0; i < VL_STEPS; i++, rayPos += increment) {
        vec4 samplePos   = shadowProjection * shadowModelView * rayPos;
        vec3 sampleColor = sampleShadowColor(viewPos, distortShadowSpace(samplePos.xyz) * 0.5 + 0.5);

        vec3 airmass      = (densities(rayPos.y) * 19900.0) * rayLength;
        vec3 opticalDepth = kExtinction * airmass;

        vec3 stepTransmittance = exp(-opticalDepth);
        vec3 visibleScattering = transmittance * clamp01((stepTransmittance - 1.0) / -opticalDepth);
        vec3 stepScattering    = kScattering * (airmass.xy * phase.xy) * visibleScattering;

        scattering    += stepScattering * vlTransmittance(rayPos.xyz, rayDir.xyz) * sampleColor * illuminance;
        transmittance *= stepTransmittance;
    }
    return max0(scattering);
}
