/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/*
    SOURCES / CREDITS:
    Thanks LVutner#5199 and Jessie#7257 for the help!

    ScratchaPixel:   https://www.scratchapixel.com/lessons/procedural-generation-virtual-worlds/simulating-sky/simulating-colors-of-the-sky
    Wikipedia:       https://fr.wikipedia.org/wiki/Th%C3%A9orie_de_Mie
    Sebastian Lague: https://www.youtube.com/watch?v=DxfEbulyFcY
    LVutner:         https://www.shadertoy.com/view/stSGRy
    gltracy:         https://www.shadertoy.com/view/lslXDr
*/

#include "/include/atmospherics/density.glsl"

vec3 atmosphereTransmittance(vec3 rayOrigin, vec3 lightDir) {
    float rayLength = raySphere(rayOrigin, lightDir, atmosRad).y / float(TRANSMITTANCE_STEPS);
    vec3 increment  = lightDir * rayLength;
    vec3 rayPos     = rayOrigin + increment * 0.5;

    vec3 accumAirmass = vec3(0.0);
    for(int j = 0; j < TRANSMITTANCE_STEPS; j++, rayPos += increment) {
        accumAirmass += densities(length(rayPos) - earthRad) * rayLength;
    }
    return exp(-kExtinction * accumAirmass);
}

// Calculating sun and moon scattering is heavier, but gives a smoother transition from day to night.

vec3 atmosphericScattering(vec3 rayOrigin, vec3 rayDir, vec3 skyIlluminance) {
    vec2 atmosDist  = raySphere(rayOrigin, rayDir, atmosRad);
    vec2 planetDist = raySphere(rayOrigin, rayDir, earthRad - 5e3);

    // Intersection method from Jessie#7257
    bool intersect = planetDist.y >= 0.0;
    float pos0 = (intersect && planetDist.x < 0.0) ? planetDist.y : max0(atmosDist.x);
    float pos1 = (intersect && planetDist.x > 0.0) ? planetDist.x : atmosDist.y;

    float rayLength = length(pos1 - pos0) / float(SCATTERING_STEPS);
    vec3 increment  = rayDir * rayLength;
    vec3 rayPos     = rayOrigin + increment * 0.5;

    float sunVdotL = dot(rayDir, sceneSunDir); float moonVdotL = dot(rayDir, sceneMoonDir);
    vec4 phase     = vec4(rayleighPhase(sunVdotL),  cornetteShanksPhase(sunVdotL, anisoFactor), 
                          rayleighPhase(moonVdotL), cornetteShanksPhase(moonVdotL, anisoFactor)
                    );

    vec3 sunScattering = vec3(0.0), moonScattering = vec3(0.0), multipleScattering = vec3(0.0), transmittance = vec3(1.0);
    
    for(int i = 0; i < SCATTERING_STEPS; i++, rayPos += increment) {
        
        vec3 airmass          = densities(length(rayPos) - earthRad) * rayLength;
        vec3 stepOpticalDepth = kExtinction * airmass;

        vec3 stepTransmittance  = exp(-stepOpticalDepth);
        vec3 visibleScattering  = transmittance * clamp01((stepTransmittance - 1.0) / -stepOpticalDepth);
        vec3 sunStepScattering  = kScattering   * (airmass.xy * phase.xy) * visibleScattering;
        vec3 moonStepScattering = kScattering   * (airmass.xy * phase.zw) * visibleScattering;

        sunScattering      += sunStepScattering  * atmosphereTransmittance(rayPos, sceneSunDir);
        moonScattering     += moonStepScattering * atmosphereTransmittance(rayPos, sceneMoonDir);
        multipleScattering += visibleScattering  * (kScattering * airmass.xy);

        transmittance *= stepTransmittance;
    }
    skyIlluminance      = PI * mix(skyIlluminance, vec3(skyIlluminance.b) * sqrt(2.0), INV_PI);
    multipleScattering *= skyIlluminance * isotropicPhase;
    
    return (sunScattering * sunIlluminance) + (moonScattering * moonIlluminance) + multipleScattering;
}

vec3 shadowLightTransmittance() {
    vec3 sunTransmit  = atmosphereTransmittance(atmosRayPos, sceneSunDir)  * sunIlluminance;
    vec3 moonTransmit = atmosphereTransmittance(atmosRayPos, sceneMoonDir) * moonIlluminance;

    return sunTransmit + moonTransmit;
}
