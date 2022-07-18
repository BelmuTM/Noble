/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/include/atmospherics/atmosphere.glsl"

vec3 getVlDensities(in float height) {
    height -= VL_ALTITUDE;

    vec2 rayleighMie    = exp(-height / scaleHeights);
         rayleighMie.x *= mix(FOG_DENSITY, FOG_RAIN_DENSITY, wetness); // Increasing aerosols for FOG to be unrealistically visible

    return vec3(rayleighMie, 0.0);
}

void groundFog(inout vec3 color, vec3 viewPos, vec3 directIlluminance, vec3 skyIlluminance, float skyLight, bool sky) {
    vec3 scenePos = viewToScene(viewPos);

    float airmass     = sky ? far : length(scenePos);
          airmass    *= mix(FOG_DENSITY, FOG_RAIN_DENSITY, wetness);
    vec3 opticalDepth = (atmosExtinctionCoeff[0] + atmosExtinctionCoeff[1] + atmosExtinctionCoeff[2]) * airmass;

    vec3 transmittance       = exp(-opticalDepth);
    vec3 transmittedFraction = clamp01((transmittance - 1.0) / -opticalDepth);

    float VdotL    = dot(normalize(scenePos), sceneShadowDir);
    vec2  phase    = vec2(rayleighPhase(VdotL), kleinNishinaPhase(VdotL, anisotropyFactor));
          skyLight = sky ? 1.0 : getSkyLightIntensity(skyLight);

	vec3 scattering  = atmosScatteringCoeff * vec2(airmass * phase)          * (directIlluminance * skyLight);
	     scattering += atmosScatteringCoeff * vec2(airmass * isotropicPhase) * (skyIlluminance    * skyLight);
	     scattering *= transmittedFraction;

    color = color * transmittance + scattering;
}

// Thanks Jessie, LVutner and SixthSurge for the help!

vec3 vlTransmittance(vec3 rayOrigin, vec3 lightDir) {
    float stepLength = 1.0 / TRANSMITTANCE_STEPS;
    vec3 increment   = lightDir * stepLength;
    vec3 rayPos      = rayOrigin + increment * 0.5;

    vec3 accumAirmass = vec3(0.0);
    for(int i = 0; i < TRANSMITTANCE_STEPS; i++, rayPos += increment) {
        accumAirmass += getVlDensities(rayPos.y) * stepLength;
    }
    return exp(-atmosExtinctionCoeff * accumAirmass);
}

void volumetricFog(inout vec3 color, vec3 viewPos, vec3 directIlluminance, vec3 skyIlluminance, float skyLight) {
    vec3 startPos = gbufferModelViewInverse[3].xyz;
    vec3 endPos   = viewToScene(viewPos);

    float jitter = fract(frameTimeCounter + bayer16(gl_FragCoord.xy));

    vec3 increment = (endPos - startPos) * rcp(VL_STEPS);
    vec3 rayPos    = startPos + increment * jitter;

    vec3 shadowStartPos  = worldToShadow(startPos);
    vec3 shadowIncrement = (worldToShadow(endPos) - shadowStartPos) * rcp(VL_STEPS);
    vec3 shadowPos       = shadowStartPos + shadowIncrement * jitter;

    float VdotL = dot(normalize(endPos), sceneShadowDir);
    vec2 phase  = vec2(rayleighPhase(VdotL), kleinNishinaPhase(VdotL, anisotropyFactor));

    mat2x3 scattering = mat2x3(vec3(0.0), vec3(0.0)); vec3 transmittance = vec3(1.0);
    float stepLength = length(increment);

    for(int i = 0; i < VL_STEPS; i++, rayPos += increment, shadowPos += shadowIncrement) {
        vec3 airmass      = getVlDensities(rayPos.y) * stepLength;
        vec3 opticalDepth = atmosExtinctionCoeff * airmass;

        vec3 stepTransmittance = exp(-opticalDepth);
        vec3 visibleScattering = transmittance * clamp01((stepTransmittance - 1.0) / -opticalDepth);

        vec3 stepScatteringDirect   = atmosScatteringCoeff * vec2(airmass.xy * phase.xy)       * visibleScattering;
        vec3 stepScatteringIndirect = atmosScatteringCoeff * vec2(airmass.xy * isotropicPhase) * visibleScattering;

        vec3 shadowColor = getShadowColor(distortShadowSpace(shadowPos) * 0.5 + 0.5);

        scattering[0] += stepScatteringDirect   * vlTransmittance(rayPos, sceneShadowDir) * shadowColor;
        scattering[1] += stepScatteringIndirect * vlTransmittance(rayPos, vec3(0.0, 1.0, 0.0));
        transmittance *= stepTransmittance;
    }

    scattering[0] *= directIlluminance;
    scattering[1] *= skyIlluminance * getSkyLightIntensity(skyLight);

    color += scattering[0] + scattering[1];
}

#if TONEMAP == 0
    const vec3 waterAbsorptionCoeff = (vec3(WATER_ABSORPTION_R, WATER_ABSORPTION_G, WATER_ABSORPTION_B) * 0.01) * sRGB_2_AP1_ALBEDO;
    const vec3 waterScatteringCoeff = (vec3(WATER_SCATTERING_R, WATER_SCATTERING_G, WATER_SCATTERING_B) * 0.01) * sRGB_2_AP1_ALBEDO;
#else 
    const vec3 waterAbsorptionCoeff = vec3(WATER_ABSORPTION_R, WATER_ABSORPTION_G, WATER_ABSORPTION_B) * 0.01;
    const vec3 waterScatteringCoeff = vec3(WATER_SCATTERING_R, WATER_SCATTERING_G, WATER_SCATTERING_B) * 0.01;
#endif

const vec3 waterExtinctionCoeff = waterAbsorptionCoeff + waterScatteringCoeff;
const int phaseMultiSamples = 8;

// Sources: ShaderLabs, Spectrum - Zombye
void waterFog(inout vec3 color, float dist, float VdotL, vec3 directIlluminance, vec3 skyIlluminance, float skyLight) {
    vec3 transmittance = exp(-waterAbsorptionCoeff * dist);

    vec3 scattering  = skyIlluminance * isotropicPhase * getSkyLightIntensity(skyLight);
         scattering += directIlluminance * cornetteShanksPhase(VdotL, 0.5);
         scattering *= waterScatteringCoeff * (1.0 - transmittance) / waterExtinctionCoeff;

    color = color * transmittance + scattering;
}

// Thanks Jessie#7257 for the help!
void volumetricWaterFog(inout vec3 color, vec3 startPos, vec3 endPos, vec3 waterDir, vec3 directIlluminance, vec3 skyIlluminance, float skyLight, float depth1) {
    float jitter = fract(frameTimeCounter + bayer16(gl_FragCoord.xy));

    vec3 increment = (endPos - startPos) * rcp(WATER_FOG_STEPS);
    vec3 rayPos    = startPos + increment * jitter;

    vec3 shadowStartPos  = worldToShadow(startPos);
    vec3 shadowIncrement = (worldToShadow(endPos) - shadowStartPos) * rcp(WATER_FOG_STEPS);
    vec3 shadowPos       = shadowStartPos + shadowIncrement * jitter;

    float rayLength = (depth1 == 1.0 ? far : distance(startPos, endPos)) * rcp(WATER_FOG_STEPS);
    float VdotL     = dot(waterDir, sceneShadowDir);

    vec3 opticalDepth       = waterExtinctionCoeff * rayLength;
    vec3 stepTransmittance  = exp(-opticalDepth);
    vec3 scatteringIntegral = (1.0 - stepTransmittance) / waterExtinctionCoeff;

    mat2x3 scattering = mat2x3(vec3(0.0), vec3(0.0)); vec3 transmittance = vec3(1.0);

    for(int i = 0; i < WATER_FOG_STEPS; i++, rayPos += increment, shadowPos += shadowIncrement) {
        vec3 shadowColor = getShadowColor(distortShadowSpace(shadowPos) * 0.5 + 0.5);

        for(int n = 0; n < 3; n++) {
            float phase = mix(kleinNishinaPhase(VdotL, 0.6), isotropicPhase, float(n) * rcp(3.0));
            float aN = pow(0.6, n), bN = pow(0.4, n);

            mat2x3 stepScattering = mat2x3(vec3(0.0), vec3(0.0));
            stepScattering[0] = exp(-opticalDepth * bN) * shadowColor * phase          * waterScatteringCoeff * scatteringIntegral;
            stepScattering[1] = exp(-opticalDepth * bN) * skyLight    * isotropicPhase * waterScatteringCoeff * scatteringIntegral;

            scattering[0] += stepScattering[0] * transmittance * aN;
            scattering[1] += stepScattering[1] * transmittance * aN;
        }
        transmittance *= stepTransmittance;
    }

    scattering[0] *= directIlluminance;
    scattering[1] *= skyIlluminance;

    // Multiple scattering approximation provided by Zombye#7365
    /*
    vec3 scatteringAlbedo     = clamp01(waterScatteringCoeff / waterExtinctionCoeff);
    vec3 multScatteringFactor = scatteringAlbedo * 0.84;

    float phaseMulti = 0.0;
    for(int i = 0; i < phaseMultiSamples; i++) {
        phaseMulti += cornetteShanksPhase(VdotL, 0.6 * pow(0.5, phaseMultiSamples));
    }
    phaseMulti /= phaseMultiSamples;

    vec3 multipleScattering  = directScattering * directIlluminance * phaseMulti;
         multipleScattering += indirectScattering * isotropicPhase;
         multipleScattering *= multScatteringFactor / (1.0 - multScatteringFactor);
    */
    
    color = color * transmittance + (scattering[0] + scattering[1]);
}
