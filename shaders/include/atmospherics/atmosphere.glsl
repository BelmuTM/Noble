/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
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
    float stepLength = intersectSphere(rayOrigin, lightDir, atmosUpperRad).y / float(TRANSMITTANCE_STEPS);
    vec3 increment   = lightDir * stepLength;
    vec3 rayPos      = rayOrigin + increment * 0.5;

    vec3 accumAirmass = vec3(0.0);
    for(int i = 0; i < TRANSMITTANCE_STEPS; i++, rayPos += increment) {
        accumAirmass += getDensities(length(rayPos)) * stepLength;
    }
    return exp(-atmosExtinctionCoeff * accumAirmass);
}

#if defined STAGE_FRAGMENT
    vec3 atmosphericScattering(vec3 rayDir, vec3 skyIlluminance) {
        vec2 dists = intersectSphericalShell(atmosRayPos, rayDir, atmosLowerRad, atmosUpperRad);
        if(dists.y < 0.0) return vec3(0.0);

        float stepLength = (dists.y - dists.x) / float(SCATTERING_STEPS);
        vec3 increment   = rayDir * stepLength;
        vec3 rayPos      = atmosRayPos + increment * 0.5;

        vec2 VdotL    = vec2(dot(rayDir, sceneSunDir), dot(rayDir, sceneMoonDir));
        vec2 phase[2] = vec2[2](
            vec2(rayleighPhase(VdotL.x), cornetteShanksPhase(VdotL.x, anisotropyFactor)), 
            vec2(rayleighPhase(VdotL.y), cornetteShanksPhase(VdotL.y, anisotropyFactor))
        );

        vec3 sunScattering = vec3(0.0), moonScattering = vec3(0.0), multipleScattering = vec3(0.0);
        vec3 transmittance = vec3(1.0);
    
        for(int i = 0; i < SCATTERING_STEPS; i++, rayPos += increment) {
            vec3 airmass          = getDensities(length(rayPos)) * stepLength;
            vec3 stepOpticalDepth = atmosExtinctionCoeff * airmass;

            vec3 stepTransmittance  = exp(-stepOpticalDepth);
            vec3 visibleScattering  = transmittance   * clamp01((stepTransmittance - 1.0) / -stepOpticalDepth);
            vec3 sunStepScattering  = atmosScatteringCoeff * (airmass.xy * phase[0]) * visibleScattering;
            vec3 moonStepScattering = atmosScatteringCoeff * (airmass.xy * phase[1]) * visibleScattering;

            sunScattering  += sunStepScattering  * atmosphereTransmittance(rayPos, sceneSunDir);
            moonScattering += moonStepScattering * atmosphereTransmittance(rayPos, sceneMoonDir);

            vec3 stepScattering    = atmosScatteringCoeff * airmass.xy;
            vec3 stepScatterAlbedo = stepScattering / stepOpticalDepth;

            vec3 multScatteringFactor = stepScatterAlbedo * 0.84;
            vec3 multScatteringEnergy = multScatteringFactor / (1.0 - multScatteringFactor);
                 multipleScattering  += multScatteringEnergy * visibleScattering * stepScattering;

            transmittance *= stepTransmittance;
        }
        multipleScattering *= (skyIlluminance * INV_PI) * isotropicPhase;
        sunScattering      *= sunIlluminance;
        moonScattering     *= moonIlluminance;
    
        return sunScattering + moonScattering + multipleScattering;
    }
#endif

vec3 sampleDirectIlluminance() {
    vec3 directIlluminance = vec3(0.0);

    #ifdef WORLD_OVERWORLD
        vec3 sunTransmit  = atmosphereTransmittance(atmosRayPos, sceneSunDir)  * sunIlluminance;
        vec3 moonTransmit = atmosphereTransmittance(atmosRayPos, sceneMoonDir) * moonIlluminance;
        directIlluminance = sunTransmit + moonTransmit;

        #if TONEMAP == 0
            directIlluminance = linearToAP1(directIlluminance);
        #endif
    #endif

    return directIlluminance;
}

vec3 sampleSkyIlluminance() {
    vec3 skyIlluminance = vec3(0.0);

    #ifdef WORLD_OVERWORLD
        const ivec2 samples = ivec2(16, 8);

        for(int x = 0; x < samples.x; x++) {
            for(int y = 0; y < samples.y; y++) {
                vec3 dir        = generateUnitVector(vec2((x + 0.5) / samples.x, 0.5 * (y + 0.5) / samples.y + 0.5)).xzy; // Uniform hemisphere sampling thanks to SixthSurge#3922
                skyIlluminance += texture(colortex0, projectSphere(dir) * ATMOSPHERE_RESOLUTION).rgb;
            }
        }
        skyIlluminance *= (TAU / (samples.x * samples.y));
    #endif

    return skyIlluminance;
}
