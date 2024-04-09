/***********************************************/
/*          Copyright (C) 2024 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

float dither = interleavedGradientNoise(gl_FragCoord.xy);

float calculateAirFogPhase(float cosTheta) {
    float forwardsLobe  = henyeyGreensteinPhase(cosTheta, airFogForwardsLobe);
    float backwardsLobe = henyeyGreensteinPhase(cosTheta,-airFogBackardsLobe);
    float forwardsPeak  = henyeyGreensteinPhase(cosTheta, airFogForwardsPeak);

    return mix(mix(forwardsLobe, backwardsLobe, airFogBackScatter), forwardsPeak, airFogPeakWeight);
}

const float aerialPerspectiveMult = 1.0;

#if defined WORLD_OVERWORLD
    vec3 airFogAttenuationCoefficients = vec3(airFogExtinctionCoefficient);
    vec3 airFogScatteringCoefficients  = vec3(airFogScatteringCoefficient);

    const float fogAltitude   = FOG_ALTITUDE;
    const float fogThickness  = FOG_THICKNESS;
          float densityFactor = wetness;
    const float densityMult   = 1.0;
#elif defined WORLD_NETHER
    const vec3 airFogAttenuationCoefficients = vec3(0.6, 0.4, 0.05);
    const vec3 airFogScatteringCoefficients  = vec3(1.0, 0.3, 0.0);

    const float fogAltitude   = max(34.0, FOG_ALTITUDE - 34.0);
    const float fogThickness  = FOG_THICKNESS * 1.8;
    const float densityFactor = 1.0;
    const float densityMult   = 1.0;
#elif defined WORLD_END
    const vec3 airFogAttenuationCoefficients = vec3(0.7, 0.5, 0.75);
    const vec3 airFogScatteringCoefficients  = vec3(0.7, 0.3, 0.8);

    const float fogAltitude   = FOG_ALTITUDE - 10.0;
    const float fogThickness  = (FOG_THICKNESS + 40.0) * 1.3;
    const float densityFactor = 1.0;
    const float densityMult   = 2.0;
#endif

float fogDensity = mix(FOG_DENSITY, 1.0, densityFactor);

#if defined WORLD_OVERWORLD

    uniform ivec2 eyeBrightness;
    uniform float rcp240;

    void computeLandAerialPerspective(out vec3 scatteringOut, out vec3 transmittanceOut, vec3 viewPosition, float VdotL, vec3 directIlluminance, vec3 skyIlluminance) {
        #if defined DISTANT_HORIZONS
            float farPlane = far * 2.0;
        #else
            float farPlane = far;
        #endif

        float airmass      = pow2(quinticStep(0.0, farPlane, length(viewPosition))) * aerialPerspectiveMult;
        vec3  opticalDepth = atmosphereAttenuationCoefficients * vec3(airmass);

        transmittanceOut = exp(-opticalDepth);

        vec2 phase = vec2(rayleighPhase(VdotL), henyeyGreensteinPhase(VdotL, mieAnisotropyFactor));

        vec3 visibleScattering = saturate((transmittanceOut - 1.0) / -opticalDepth);

        scatteringOut  = atmosphereScatteringCoefficients * vec2(phase * airmass) * visibleScattering;
        scatteringOut *= directIlluminance * skyIlluminance * eyeBrightness.y * rcp240;
    }
    
#endif

#if AIR_FOG == 2

    void computeAirFogApproximation(out vec3 scatteringOut, out vec3 transmittanceOut, vec3 viewPosition, float VdotL, vec3 directIlluminance, vec3 skyIlluminance, float skylight) {
        float airmass    = quinticStep(0.0, far, length(viewPosition)) * fogDensity * densityMult;
        transmittanceOut = exp(-airFogAttenuationCoefficients * airmass * 10.0);

        scatteringOut  = skyIlluminance    * isotropicPhase * skylight;
        scatteringOut += directIlluminance * calculateAirFogPhase(VdotL);
        scatteringOut *= airFogScatteringCoefficients * ((1.0 - transmittanceOut) / airFogAttenuationCoefficients);
    }

#elif AIR_FOG == 1

    float getAirFogDensity(vec3 position) {
        if(clamp(position.y, fogAltitude, fogAltitude + fogThickness) != position.y) return 0.0;

        float altitude   = (position.y - fogAltitude) * rcp(fogThickness);
        float shapeAlter = remap(altitude, 0.0, 0.2, 0.0, 1.0) * remap(altitude, 0.9, 1.0, 1.0, 0.0);
        
        float shapeNoise  = pow2(FBM(position * 0.1, AIR_FOG_OCTAVES, 0.7) * 2.0 - 1.0);
              shapeNoise  = shapeNoise * shapeAlter * 0.4 - (2.0 * shapeAlter * altitude * 0.5 + 0.5);
              shapeNoise *= exp(-max0(position.y - fogAltitude) * 0.2);
        
        return saturate(shapeNoise) * fogDensity * densityMult;
    }

    /*
    float getFogTransmittance(vec3 rayOrigin, vec3 lightDir) {
        const float stepSize = 1.0 / VL_TRANSMITTANCE_STEPS;
        vec3 increment   = lightDir * stepSize;
        vec3 rayPosition = rayOrigin + increment * 0.5;

        float accumAirmass = 0.0;
        for(int i = 0; i < VL_TRANSMITTANCE_STEPS; i++, rayPosition += increment) {
            accumAirmass += getAirFogDensity(rayPosition) * stepSize;
        }
        return exp(-airFogExtinctionCoefficient * accumAirmass);
    }
    */

    void computeVolumetricAirFog(inout vec3 scatteringOut, inout vec3 transmittanceOut, vec3 startPosition, vec3 endPosition, vec3 viewPosition, float farPlane, float VdotL, vec3 directIlluminance, vec3 skyIlluminance) {
        if(fogDensity < 1e-3) return;

        const float stepSize = 1.0 / AIR_FOG_SCATTERING_STEPS;
        
        vec3 increment    = (endPosition - startPosition) * stepSize;
        vec3 rayPosition  = startPosition + increment * dither;
             rayPosition += cameraPosition;

        vec3 shadowStartPosition = worldToShadow(startPosition);
        vec3 shadowIncrement     = (worldToShadow(endPosition) - shadowStartPosition) * stepSize;
        vec3 shadowPosition      = shadowStartPosition + shadowIncrement * dither;

        float rayLength = length(increment);
        float phase     = calculateAirFogPhase(VdotL);

        float perspective = quinticStep(0.0, 1.0, length(normalize(cameraPosition)));

        for(int i = 0; i < AIR_FOG_SCATTERING_STEPS; i++, rayPosition += increment, shadowPosition += shadowIncrement) {
            float distanceFalloff = quinticStep(0.0, 1.0, exp2(-2.0 * length(rayPosition - cameraPosition) / farPlane));

            float density = getAirFogDensity(rayPosition) * distanceFalloff;

            if(density < EPS) continue;

            #if defined WORLD_OVERWORLD
                vec3 shadowColor = getShadowColor(distortShadowSpace(shadowPosition) * 0.5 + 0.5);

                #if CLOUDS_SHADOWS == 1 && CLOUDS_LAYER0_ENABLED == 1
                    shadowColor *= getCloudsShadows(rayPosition);
                #endif
            #else
                vec3 shadowColor = vec3(1.0);
            #endif

            float airmass      = density * rayLength;
            vec3  opticalDepth = airFogAttenuationCoefficients * airmass;

            vec3 stepTransmittance = exp(-opticalDepth);
            vec3 visibleScattering = transmittanceOut * saturate((stepTransmittance - 1.0) / -opticalDepth);

            vec3 stepScatteringDirect   = airFogScatteringCoefficients * airmass * phase          * directIlluminance * visibleScattering * shadowColor;
            vec3 stepScatteringIndirect = airFogScatteringCoefficients * airmass * isotropicPhase * skyIlluminance    * visibleScattering;

            #if defined WORLD_OVERWORLD
                stepScatteringIndirect *= eyeBrightness.y * rcp240;
            #endif

            scatteringOut    += stepScatteringDirect + stepScatteringIndirect;
            transmittanceOut *= stepTransmittance;
        }
    }

#endif

#if TONEMAP == ACES
    const vec3 waterAbsorptionCoefficients = (vec3(WATER_ABSORPTION_R, WATER_ABSORPTION_G, WATER_ABSORPTION_B) * 0.01) * SRGB_2_AP1_ALBEDO;
    const vec3 waterScatteringCoefficients = (vec3(WATER_SCATTERING_R, WATER_SCATTERING_G, WATER_SCATTERING_B) * 0.01) * SRGB_2_AP1_ALBEDO;
#else 
    const vec3 waterAbsorptionCoefficients = vec3(WATER_ABSORPTION_R, WATER_ABSORPTION_G, WATER_ABSORPTION_B) * 0.01;
    const vec3 waterScatteringCoefficients = vec3(WATER_SCATTERING_R, WATER_SCATTERING_G, WATER_SCATTERING_B) * 0.01;
#endif

vec3 waterExtinctionCoefficients = saturate(waterScatteringCoefficients + waterAbsorptionCoefficients);

#if WATER_FOG == 0

    void computeWaterFogApproximation(out vec3 scatteringOut, out vec3 transmittanceOut, vec3 startPosition, vec3 endPosition, float VdotL, vec3 directIlluminance, vec3 skyIlluminance, float skylight) {
        transmittanceOut = exp(-waterAbsorptionCoefficients * distance(startPosition, endPosition));

        scatteringOut  = skyIlluminance    * isotropicPhase * skylight;
        scatteringOut += directIlluminance * kleinNishinaPhase(VdotL, 0.5);
        scatteringOut *= waterScatteringCoefficients * (1.0 - transmittanceOut) / waterAbsorptionCoefficients;
    }

#else

    void computeVolumetricWaterFog(out vec3 scatteringOut, out vec3 transmittanceOut, vec3 startPosition, vec3 endPosition, float VdotL, vec3 directIlluminance, vec3 skyIlluminance, float skylight, bool sky) {
        const float stepSize = 1.0 / WATER_FOG_STEPS;

        vec3 worldIncrement = (endPosition - startPosition) * stepSize;
        vec3 worldPosition  = startPosition + worldIncrement * dither;
             worldPosition += cameraPosition;

        vec3 shadowIncrement = mat3(shadowModelView) * worldIncrement;
             shadowIncrement = diagonal3(shadowProjection) * shadowIncrement;
        vec3 shadowPosition  = worldToShadow(worldPosition - cameraPosition);

        float rayLength = sky ? far : length(worldIncrement);

        vec3 stepTransmittance = exp(-waterExtinctionCoefficients * rayLength);

        vec3 scattering    = vec3(0.0); 
        vec3 transmittance = vec3(1.0);

        for(int i = 0; i < WATER_FOG_STEPS; i++, worldPosition += worldIncrement, shadowPosition += shadowIncrement) {
            vec3  shadowScreenPosition = distortShadowSpace(shadowPosition) * 0.5 + 0.5;
            ivec2 shadowTexel          = ivec2(shadowScreenPosition.xy * shadowMapResolution);

            float shadowDepth0 = texelFetch(shadowtex0, shadowTexel, 0).r;
            vec3  shadow       = getShadowColor(shadowScreenPosition);

            float distanceThroughWater = abs(shadowDepth0 - shadowScreenPosition.z) * -shadowProjectionInverse[2].z / SHADOW_DEPTH_STRETCH;

            #if CLOUDS_SHADOWS == 1 && CLOUDS_LAYER0_ENABLED == 1
                shadow *= getCloudsShadows(worldPosition);
            #endif

            vec3 directTransmittance = shadow * exp(-waterExtinctionCoefficients * distanceThroughWater);

            scattering += transmittance * directIlluminance * directTransmittance;
            scattering += transmittance * skyIlluminance    * isotropicPhase * skylight;
            
            transmittance *= stepTransmittance;
        }

        vec3 scatteringAlbedo = saturate(waterScatteringCoefficients / waterExtinctionCoefficients);

        scattering *= (1.0 - stepTransmittance) * scatteringAlbedo;

        // Multiple scattering approximation provided by Jessie
        vec3 multipleScatteringFactor = scatteringAlbedo * 0.84;

        int phaseSampleCount = 32;
        float phaseMultiple  = 0.0;

        for(int i = 0; i < phaseSampleCount; i++) {
            phaseMultiple += cornetteShanksPhase(VdotL, 0.6 * pow(0.5, phaseSampleCount));
        }
        phaseMultiple /= phaseSampleCount;

        scatteringOut  = scattering * phaseMultiple;
        scatteringOut *= multipleScatteringFactor / (1.0 - multipleScatteringFactor);

        transmittanceOut = transmittance;
    }

#endif
