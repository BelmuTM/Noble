/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/include/atmospherics/atmosphere.glsl"

vec3 fog(vec3 viewPos, vec3 fogColorStart, vec3 fogColorEnd, float fogCoef, float density) {
    if(isEyeInWater == 1) {
        vec3 skyIlluminance = texture(colortex7, projectSphere(vec3(0.0, 1.0, 0.0)) * ATMOSPHERE_RESOLUTION).rgb;
        fogColorEnd = skyIlluminance;
        density = 0.7;
    }
    const float sqrt2 = -sqrt(2.0);
    float d = density * pow(-viewPos.z - near, 0.6);

    float fogDensity = 1.0 - clamp01(exp2(d * d * sqrt2));
    return mix(fogColorStart, fogColorEnd, fogDensity) * clamp01(fogCoef);
}

// Thanks Jessie, LVutner and SixthSurge for the help!

vec3 vlTransmittance(vec3 rayOrigin, vec3 lightDir) {
    float stepSize = (25.0 / TRANSMITTANCE_STEPS) / abs(lightDir.y);
    vec3 increment = lightDir * stepSize;
    vec3 rayPos = rayOrigin + increment * 0.5;

    vec3 transmittance = vec3(1.0);
    for(int j = 0; j < TRANSMITTANCE_STEPS; j++) {
        vec3 density = densities(rayPos.y);
        transmittance *= exp(-kExtinction * density * stepSize);
        rayPos += increment;
    }
    return transmittance;
}

vec3 volumetricLighting(vec3 viewPos) {
    vec4 startPos  = gbufferModelViewInverse * vec4(0.0, 0.0, 0.0, 1.0);
    vec4 endPos    = gbufferModelViewInverse * vec4(viewPos, 1.0);
    float stepSize = distance(startPos, endPos) / float(VL_STEPS);

    float jitter = fract(frameTimeCounter + bayer16(gl_FragCoord.xy));
    vec4 rayDir  = (normalize(endPos - startPos) * stepSize) * jitter;
    vec4 rayPos  = startPos + rayDir * stepSize;

    float VdotL = dot(normalize(endPos + startPos).xyz, worldTime <= 12750 ? playerSunDir : playerMoonDir);
    vec2 phase = vec2(rayleighPhase(VdotL), miePhase(VdotL));

    vec3 scattering = vec3(0.0), transmittance = vec3(1.0);
    vec3 illuminance = (worldTime <= 12750 ? SUN_ILLUMINANCE : MOON_ILLUMINANCE);

    for(int i = 0; i < VL_STEPS; i++, rayPos += rayDir) {
        vec4 samplePos   = shadowProjection * shadowModelView * rayPos;
        vec3 sampleColor = sampleShadowColor(vec3(distort(samplePos.xy), samplePos.z) * 0.5 + 0.5);

        vec3 airmass     = (densities(rayPos.y) * VL_DENSITY) * stepSize;
        vec3 opticalDepth = kExtinction * airmass;

        vec3 stepTransmittance = exp(-opticalDepth);
        vec3 visibleScattering = transmittance * clamp01((stepTransmittance - 1.0) / -opticalDepth);
        vec3 stepScattering    = kScattering * (airmass.xy * phase.xy) * visibleScattering;

        scattering    += stepScattering * vlTransmittance(rayPos.xyz, rayDir.xyz) * sampleColor * illuminance;
        transmittance *= stepTransmittance;
    }
    return scattering;
}
