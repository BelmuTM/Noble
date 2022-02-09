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
    float stepLength = intersectSphere(rayOrigin, lightDir, atmosRad).y / float(TRANSMITTANCE_STEPS);
    vec3 increment  = lightDir * stepLength;
    vec3 rayPos     = rayOrigin + increment * 0.5;

    vec3 accumAirmass = vec3(0.0);
    for(int j = 0; j < TRANSMITTANCE_STEPS; j++, rayPos += increment) {
        accumAirmass += densities(length(rayPos) - earthRad) * stepLength;
    }
    return exp(-kExtinction * accumAirmass);
}

#if defined STAGE_FRAGMENT
    vec3 atmosphericScattering(vec3 rayDir, vec3 skyIlluminance) {
        vec2 dists = intersectSphericalShell(atmosRayPos, rayDir, earthRad - 5e3, atmosRad);
        if(dists.y < 0.0) return vec3(0.0);

        float stepLength = (dists.y - dists.x) / float(SCATTERING_STEPS);
        vec3 increment   = rayDir * stepLength;
        vec3 rayPos      = atmosRayPos + increment * 0.5;

        float sunVdotL = dot(rayDir, sceneSunDir); float moonVdotL = dot(rayDir, sceneMoonDir);
        vec4 phase     = vec4(rayleighPhase(sunVdotL),  cornetteShanksPhase(sunVdotL, anisoFactor), 
                          rayleighPhase(moonVdotL), cornetteShanksPhase(moonVdotL, anisoFactor)
                    );

        vec3 sunScattering = vec3(0.0), moonScattering = vec3(0.0), multipleScattering = vec3(0.0), transmittance = vec3(1.0);
    
        for(int i = 0; i < SCATTERING_STEPS; i++, rayPos += increment) {
        
            vec3 airmass          = densities(length(rayPos) - earthRad) * stepLength;
            vec3 stepOpticalDepth = kExtinction * airmass;

            vec3 stepTransmittance  = exp(-stepOpticalDepth);
            vec3 visibleScattering  = transmittance * clamp01((stepTransmittance - 1.0) / -stepOpticalDepth);
            vec3 sunStepScattering  = kScattering   * (airmass.xy * phase.xy) * visibleScattering;
            vec3 moonStepScattering = kScattering   * (airmass.xy * phase.zw) * visibleScattering;

            sunScattering  += sunStepScattering  * atmosphereTransmittance(rayPos, sceneSunDir);
            moonScattering += moonStepScattering * atmosphereTransmittance(rayPos, sceneMoonDir);

            vec3 stepScattering    = kScattering * airmass.xy;
            vec3 stepScatterAlbedo = stepScattering / stepOpticalDepth;

            vec3 multScatterFactor = 0.84 * stepScatterAlbedo;
            vec3 multScatterEnergy = multScatterFactor / (1.0 - multScatterFactor);
            multipleScattering    += multScatterEnergy * visibleScattering * stepScattering;

            transmittance *= stepTransmittance;
        }
        multipleScattering *= (skyIlluminance * INV_PI) * isotropicPhase;
    
        return (sunScattering * sunIlluminance) + (moonScattering * moonIlluminance) + multipleScattering;
    }
#endif

vec3 shadowLightTransmittance() {
    vec3 sunTransmit  = atmosphereTransmittance(atmosRayPos, sceneSunDir)  * sunIlluminance;
    vec3 moonTransmit = atmosphereTransmittance(atmosRayPos, sceneMoonDir) * moonIlluminance;

    return sunTransmit + moonTransmit;
}
