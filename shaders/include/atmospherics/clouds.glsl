/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/include/atmospherics/atmosphere.glsl"

vec3 cloudsTransmittance(vec3 rayOrigin, vec3 lightDir) {
    float stepLength = intersectSphere(rayOrigin, lightDir, atmosRad).y / float(TRANSMITTANCE_STEPS);
    vec3 increment  = lightDir * stepLength;
    vec3 rayPos     = rayOrigin + increment * 0.5;

    vec3 accumAirmass = vec3(0.0);
    for(int j = 0; j < TRANSMITTANCE_STEPS; j++, rayPos += increment) {
        accumAirmass += cloudDensity(length(rayPos) - inCloudRad) * stepLength;
    }
    return exp(-kExtinction * accumAirmass);
}

// Calculating sun and moon scattering is heavier, but gives a smoother transition from day to night.

vec3 cloudsScattering(vec3 rayDir, vec3 skyIlluminance) {
    vec2 dists = intersectSphericalShell(atmosRayPos, rayDir, innerCloudRad, outerCloudRad);
    if(dists.y < 0.0) return vec3(0.0);

    float stepLength = (dists.y - dists.x) / float(CLOUDS_STEPS);
    vec3 increment   = rayDir * stepLength;
    vec3 rayPos      = atmosRayPos + rayDir * (dists.x + bayer2(gl_FragCoord.xy) * stepLength);

    float sunVdotL = dot(rayDir, sceneSunDir); float moonVdotL = dot(rayDir, sceneMoonDir);
    vec4 phase     = vec4(rayleighPhase(sunVdotL),  cornetteShanksPhase(sunVdotL, anisoFactor), 
                          rayleighPhase(moonVdotL), cornetteShanksPhase(moonVdotL, anisoFactor)
                    );

    vec3 scattering = vec3(0.0), transmittance = vec3(1.0);
    
    for(int i = 0; i < CLOUDS_STEPS; i++, rayPos += increment) {
        

    }

}