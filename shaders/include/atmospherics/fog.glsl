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
         rayleighMie.x *= mix(VL_DENSITY, VL_RAIN_DENSITY, wetness); // Increasing aerosols for VL to be unrealistically visible

    return vec3(rayleighMie, 0.0);
}

void groundFog(inout vec3 color, vec3 viewPos, vec3 directIlluminance, vec3 skyIlluminance, float skyLight, bool sky) {
    vec3 scenePos = viewToScene(viewPos);

    float airmass     = sky ? far : length(scenePos);
          airmass    *= RAIN_FOG_DENSITY * wetness;
    vec3 opticalDepth = (atmosExtinctionCoeff[0] + atmosExtinctionCoeff[1] + atmosExtinctionCoeff[2]) * airmass;

    vec3 transmittance       = exp(-opticalDepth);
    vec3 transmittedFraction = clamp01((transmittance - 1.0) / -opticalDepth);

    float VdotL    = dot(normalize(scenePos), sceneShadowDir);
    vec2  phase    = vec2(rayleighPhase(VdotL), kleinNishinaPhase(VdotL, atmosEnergyParam));
          skyLight = sky ? 1.0 : getSkyLightIntensity(skyLight);

	vec3 scattering  = atmosScatteringCoeff * (airmass * phase)                * (directIlluminance * skyLight);
	     scattering += atmosScatteringCoeff * (airmass * vec2(isotropicPhase)) * (skyIlluminance    * skyLight);
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

vec3 volumetricFog(vec3 viewPos, vec3 directIlluminance, vec3 skyIlluminance, float skyLight) {
    vec3 startPos = gbufferModelViewInverse[3].xyz;
    vec3 endPos   = viewToScene(viewPos);

    float jitter = fract(frameTimeCounter + bayer16(gl_FragCoord.xy));

    vec3 increment = (endPos - startPos) * rcp(VL_STEPS);
    vec3 rayPos    = startPos + increment * jitter;

    vec3 shadowStartPos  = worldToShadow(startPos);
    vec3 shadowIncrement = (worldToShadow(endPos) - shadowStartPos) * rcp(VL_STEPS);
    vec3 shadowPos       = shadowStartPos + shadowIncrement * jitter;

    float VdotL = dot(normalize(endPos), sceneShadowDir);
    vec2 phase  = vec2(rayleighPhase(VdotL), kleinNishinaPhase(VdotL, atmosEnergyParam));

    vec3 directScattering = vec3(0.0), indirectScattering = vec3(0.0), transmittance = vec3(1.0);
    float stepLength = length(increment);

    for(int i = 0; i < VL_STEPS; i++, rayPos += increment, shadowPos += shadowIncrement) {
        vec3 airmass      = getVlDensities(rayPos.y) * stepLength;
        vec3 opticalDepth = atmosExtinctionCoeff * airmass;

        vec3 stepTransmittance = exp(-opticalDepth);
        vec3 visibleScattering = transmittance * clamp01((stepTransmittance - 1.0) / -opticalDepth);

        vec3 stepScatteringDirect   = atmosScatteringCoeff * vec2(airmass.xy * phase.xy) * visibleScattering;
        vec3 stepScatteringIndirect = atmosScatteringCoeff * vec2(airmass.xy * isotropicPhase) * visibleScattering;

        vec3 sampleColor = getShadowColor(distortShadowSpace(shadowPos) * 0.5 + 0.5);

        directScattering   += stepScatteringDirect   * vlTransmittance(rayPos, sceneShadowDir) * sampleColor;
        indirectScattering += stepScatteringIndirect * vlTransmittance(rayPos, vec3(0.0, 1.0, 0.0));
        transmittance      *= stepTransmittance;
    }

    vec3 scattering  = directScattering   * directIlluminance;
         scattering += indirectScattering * skyIlluminance * getSkyLightIntensity(skyLight);

    return max0(scattering);
}

vec3 waterAbsorptionCoeff = (vec3(WATER_ABSORPTION_R, WATER_ABSORPTION_G, WATER_ABSORPTION_B) / 100.0);
vec3 waterScatteringCoeff = (vec3(WATER_SCATTERING_R, WATER_SCATTERING_G, WATER_SCATTERING_B) / 100.0);
vec3 waterExtinctionCoeff = waterAbsorptionCoeff + waterScatteringCoeff;

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
void volumetricWaterFog(inout vec3 color, vec3 startPos, vec3 endPos, vec3 waterDir, vec3 directIlluminance, vec3 skyIlluminance) {
    float jitter = fract(frameTimeCounter + bayer16(gl_FragCoord.xy));

    vec3 increment = (endPos - startPos) * rcp(WATER_FOG_STEPS);
    vec3 rayPos    = startPos + increment * jitter;

    vec3 shadowStartPos  = worldToShadow(startPos);
    vec3 shadowIncrement = (worldToShadow(endPos) - shadowStartPos) * rcp(WATER_FOG_STEPS);
    vec3 shadowPos       = shadowStartPos + shadowIncrement * jitter;

    float rayLength = (isSky(texCoords) ? far : distance(startPos, endPos)) * rcp(WATER_FOG_STEPS);
    float VdotL     = dot(waterDir, sceneShadowDir);

    vec3 opticalDepth            = waterExtinctionCoeff * rayLength;
    vec3 stepTransmittance       = exp(-opticalDepth);
    vec3 stepTransmittedFraction = clamp01((stepTransmittance - 1.0) / -opticalDepth);

    vec3 directScattering = vec3(0.0), indirectScattering = vec3(0.0), transmittance = vec3(1.0);

    for(int i = 0; i < WATER_FOG_STEPS; i++, rayPos += increment, shadowPos += shadowIncrement) {
        vec3 sampleColor = getShadowColor(distortShadowSpace(shadowPos) * 0.5 + 0.5);

        directScattering   += transmittance * sampleColor;
        indirectScattering += transmittance * skyIlluminance;
        transmittance      *= stepTransmittance;
    }

    vec3 scattering  = directScattering * directIlluminance * cornetteShanksPhase(VdotL, 0.5);
         scattering *= waterScatteringCoeff  * (1.0 - stepTransmittance) / waterExtinctionCoeff;

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
    
    color = color * transmittance + scattering;
}
