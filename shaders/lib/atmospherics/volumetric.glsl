/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec3 computeVL(vec3 viewPos) {
    vec3 worldStartPos  = mat3(gbufferModelViewInverse) * viewPos;
    vec3 worldEndPos    = viewToWorld(viewPos);
    float worldStepSize = distance(worldStartPos, worldEndPos) / float(VL_SAMPLES);

    vec3 worldDir  = normalize(worldEndPos - worldStartPos) * worldStepSize;
    vec3 worldPos  = worldStartPos + worldDir * worldStepSize;

    vec3 shadowStartPos  = projMAD3(shadowProjection, transMAD3(shadowModelView, gbufferModelViewInverse[3].xyz));
    vec3 shadowEndPos    = projMAD3(shadowProjection, transMAD3(shadowModelView, worldStartPos));
    float shadowStepSize = distance(shadowStartPos, shadowEndPos) / float(VL_SAMPLES);

    float jitter = fract(frameTimeCounter + bayer16(gl_FragCoord.xy));
    vec3 shadowDir  = (normalize(shadowEndPos - shadowStartPos) * shadowStepSize) * jitter;
    vec3 shadowPos  = shadowStartPos + shadowDir * shadowStepSize;

    float VdotL = max(0.0, dot(normalize(worldStartPos), normalize(mat3(gbufferModelViewInverse) * shadowLightPosition)));
    vec2 phase  = vec2(rayleighPhase(VdotL), miePhase(VdotL));

    vec3 scattering = vec3(0.0), transmittance = vec3(1.0), opticalDepth = vec3(0.0);
    
    for(int i = 0; i < VL_SAMPLES; i++) {
        vec3 samplePos   = vec3(distort(shadowPos.xy), shadowPos.z) * 0.5 + 0.5;
        vec3 sampleColor = sampleShadowColor(samplePos);

        vec3 airmass = densities(worldPos.y) * shadowStepSize;
        vec3 stepOpticalDepth = kExtinction * airmass;
        opticalDepth  += airmass;

        vec3 stepTransmittance  = exp(-(kExtinction * opticalDepth));
        vec3 scatteringIntegral = transmittance * ((stepTransmittance - 1.0) / -stepOpticalDepth);
        vec3 stepScattering     = kScattering * (airmass.xy * phase) * scatteringIntegral;

        scattering    += sampleColor * stepScattering * 22.0;
        transmittance *= stepTransmittance;

        shadowPos     += shadowDir;
        worldPos      += worldDir;
    }
    return scattering;
}
