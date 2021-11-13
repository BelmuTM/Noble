/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

// Thanks Jessie, LVutner and SixthSurge for the help!

vec3 volumetricLighting(vec3 viewPos) {
    vec3 startPos  = gbufferModelViewInverse[3].xyz;
    vec3 endPos    = mat3(gbufferModelViewInverse) * viewPos;
    float stepSize = distance(startPos, endPos) / float(SCATTER_STEPS);

    float jitter = fract(frameTimeCounter + bayer16(gl_FragCoord.xy));
    vec3 rayDir  = (normalize(endPos - startPos) * stepSize) * jitter;
    vec3 rayPos  = startPos + rayDir * stepSize;

    float VdotL = max(0.0, dot(normalize(endPos + startPos), worldTime <= 12750 ? playerSunDir : playerMoonDir));
    float phase = miePhase(VdotL);

    vec3 scattering = vec3(0.0), transmittance = vec3(1.0);

    for(int i = 0; i < SCATTER_STEPS; i++) {
        vec3 samplePos   = projMAD3(shadowProjection, transMAD3(shadowModelView, rayPos));
        vec3 sampleColor = sampleShadowColor(vec3(distort(samplePos.xy), samplePos.z) * 0.5 + 0.5);

        float airmass         = densities(rayPos.y).y * stepSize;
        vec3 stepOpticalDepth = kExtinction[1] * airmass;

        vec3 stepTransmittance = exp(-stepOpticalDepth);
        vec3 visibleScattering = transmittance * ((stepTransmittance - 1.0) / -stepOpticalDepth);
        vec3 stepScattering    = kScattering[1] * (airmass * phase) * visibleScattering;

        scattering    += sampleColor * stepScattering * (worldTime <= 12750 ? SUN_ILLUMINANCE : MOON_ILLUMINANCE);
        transmittance *= stepTransmittance;
        rayPos        += rayDir;
    }
    return scattering;
}
