/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/include/atmospherics/atmosphere.glsl"

void groundFog(inout vec3 color, vec3 viewPos, float skyLight, bool sky) {
    vec3 scenePos = viewToScene(viewPos);

    float airmass     = sky ? far : length(scenePos);
          airmass    *= RAIN_FOG_DENSITY * wetness;
    vec3 opticalDepth = (extinctionCoeff[0] + extinctionCoeff[1] + extinctionCoeff[2]) * airmass;

    vec3 transmittance       = exp(-opticalDepth);
    vec3 transmittedFraction = clamp01((transmittance - 1.0) / -opticalDepth);

    float VdotL    = dot(normalize(scenePos), sceneShadowDir);
    vec2  phase    = vec2(rayleighPhase(VdotL), cornetteShanksPhase(VdotL, anisotropyFactor));
          skyLight = sky ? 1.0 : pow2(1.0 - pow3(1.0 - clamp01(skyLight)));

    vec3 skyIlluminance = texture(colortex6, texCoords).rgb;

	vec3 scattering  = scatteringCoeff * (airmass * phase)                * (sampleDirectIlluminance() * skyLight);
	     scattering += scatteringCoeff * (airmass * vec2(isotropicPhase)) * (skyIlluminance * skyLight);
	     scattering *= transmittedFraction;

    color = color * transmittance + scattering;
}

// Thanks Jessie, LVutner and SixthSurge for the help!

vec3 vlTransmittance(vec3 rayOrigin, vec3 lightDir) {
    float stepLength = 1.0 / TRANSMITTANCE_STEPS;
    vec3 increment  = lightDir * stepLength;
    vec3 rayPos     = rayOrigin + increment * 0.5;

    vec3 accumAirmass = vec3(0.0);
    for(int j = 0; j < TRANSMITTANCE_STEPS; j++, rayPos += increment) {
        accumAirmass += getVlDensities(rayPos.y) * stepLength;
    }
    return exp(-extinctionCoeff * accumAirmass);
}

vec3 volumetricLighting(vec3 viewPos) {
    vec3 startPos = gbufferModelViewInverse[3].xyz;
    vec3 endPos   = viewToScene(viewPos);

    float jitter = fract(frameTimeCounter + bayer16(gl_FragCoord.xy));

    vec3 increment = (endPos - startPos) / float(VL_STEPS);
    vec3 rayPos    = startPos + increment * jitter;

    vec3 shadowStartPos  = worldToShadow(startPos);
    vec3 shadowIncrement = (worldToShadow(endPos) - shadowStartPos) / float(VL_STEPS);
    vec3 shadowPos       = shadowStartPos + shadowIncrement * jitter;

    float VdotL = dot(normalize(endPos), sceneShadowDir);
    vec2 phase  = vec2(rayleighPhase(VdotL), cornetteShanksPhase(VdotL, anisotropyFactor));

    vec3 directScattering = vec3(0.0), indirectScattering = vec3(0.0), transmittance = vec3(1.0);
    float stepLength = length(increment);

    for(int i = 0; i < VL_STEPS; i++, rayPos += increment, shadowPos += shadowIncrement) {
        vec3 airmass      = getVlDensities(rayPos.y) * stepLength;
        vec3 opticalDepth = extinctionCoeff * airmass;

        vec3 stepTransmittance = exp(-opticalDepth);
        vec3 visibleScattering = transmittance * clamp01((stepTransmittance - 1.0) / -opticalDepth);

        vec3 stepScatteringDirect   = scatteringCoeff * vec2(airmass.xy * phase.xy) * visibleScattering;
        vec3 stepScatteringIndirect = scatteringCoeff * vec2(airmass.xy * vec2(isotropicPhase)) * visibleScattering;

        vec3 sampleColor = getShadowColor(distortShadowSpace(shadowPos) * 0.5 + 0.5, 0.0);

        directScattering   += stepScatteringDirect   * vlTransmittance(rayPos, sceneShadowDir) * sampleColor;
        indirectScattering += stepScatteringIndirect * vlTransmittance(rayPos, vec3(0.0, 1.0, 0.0));
        transmittance      *= stepTransmittance;
    }
    
    vec3 skyIlluminance = texture(colortex6, texCoords).rgb;

    vec3 scattering  = directScattering   * sampleDirectIlluminance();
         scattering += indirectScattering * skyIlluminance;

    return max0(scattering);
}

vec3 waterAbsorptionCoeff = (vec3(WATER_ABSORPTION_R, WATER_ABSORPTION_G, WATER_ABSORPTION_B) / 100.0);
vec3 waterScatteringCoeff = (vec3(WATER_SCATTERING_R, WATER_SCATTERING_G, WATER_SCATTERING_B) / 100.0) * WATER_DENSITY;
vec3 waterExtinctionCoeff = waterAbsorptionCoeff + waterScatteringCoeff;

const int phaseMultiSamples = 8;

// Sources: ShaderLabs, Spectrum - Zombye
void waterFog(inout vec3 color, float dist, float VdotL, vec3 skyIlluminance, float skyLight) {
    vec3 transmittance = exp(-waterAbsorptionCoeff * WATER_DENSITY * dist);

    vec3 scattering  = skyIlluminance * isotropicPhase * pow2(quintic(0.0, 1.0, skyLight));
         scattering += (sunAngle < 0.5 ? sunIlluminance : moonIlluminance) * cornetteShanksPhase(VdotL, 0.5);
         scattering *= waterScatteringCoeff * (1.0 - transmittance) / waterExtinctionCoeff;

    color = color * transmittance + scattering;
}

// Thanks Jessie#7257 for the help!
void volumetricWaterFog(inout vec3 color, vec3 startPos, vec3 endPos, vec3 waterDir, vec3 skyIlluminance, float skyLight) {
    float jitter = fract(frameTimeCounter + bayer16(gl_FragCoord.xy));

    vec3 increment = (endPos - startPos) / float(WATER_FOG_STEPS);
    vec3 rayPos    = startPos + increment * jitter;

    vec3 shadowStartPos  = worldToShadow(startPos);
    vec3 shadowIncrement = (worldToShadow(endPos) - shadowStartPos) / float(WATER_FOG_STEPS);
    vec3 shadowPos       = shadowStartPos + shadowIncrement * jitter;

    float rayLength = (isSky(texCoords) ? far : distance(startPos, endPos)) / float(WATER_FOG_STEPS);
    float VdotL     = dot(waterDir, sceneShadowDir);

    vec3 opticalDepth            = waterExtinctionCoeff * WATER_DENSITY * rayLength;
    vec3 stepTransmittance       = exp(-opticalDepth);
    vec3 stepTransmittedFraction = clamp01((stepTransmittance - 1.0) / -opticalDepth);

    vec3 directScattering = vec3(0.0), indirectScattering = vec3(0.0), transmittance = vec3(1.0);

    for(int i = 0; i < WATER_FOG_STEPS; i++, rayPos += increment, shadowPos += shadowIncrement) {
        vec3 sampleColor  = getShadowColor(distortShadowSpace(shadowPos) * 0.5 + 0.5, 0.0);
        //vec3 visibleScattering = stepTransmittance * stepTransmittedFraction;

        directScattering   += transmittance * sampleColor;
        indirectScattering += transmittance;
        transmittance      *= stepTransmittance;
    }

    vec3 scattering  = directScattering * sampleDirectIlluminance() * cornetteShanksPhase(VdotL, 0.5);
         scattering *= waterScatteringCoeff  * (1.0 - stepTransmittance) / waterExtinctionCoeff;

    /*
    // Multiple scattering approximation provided by Jessie#7257
    vec3 scatteringAlbedo     = clamp01(waterScatteringCoeff / waterExtinctionCoeff);
    vec3 multScatteringFactor = scatteringAlbedo * 0.84;

    float phaseMulti = 0.0;
    for(int i = 0; i < phaseMultiSamples; i++) {
        phaseMulti += cornetteShanksPhase(VdotL, 0.6 * pow(0.5, phaseMultiSamples));
    }
    phaseMulti /= phaseMultiSamples;

    vec3 multipleScattering  = scattering * phaseMulti;
         multipleScattering += indirectScattering * pow2(quintic(0.0, 1.0, skyLight)) * phaseMulti;
         multipleScattering *= multScatteringFactor / (1.0 - multScatteringFactor);
    */

    color = color * transmittance + scattering;
}
