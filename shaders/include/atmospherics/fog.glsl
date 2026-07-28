/********************************************************************************/
/*                                                                              */
/*    Noble Shaders                                                             */
/*    Copyright (C) 2026  Belmu                                                 */
/*                                                                              */
/*    This program is free software: you can redistribute it and/or modify      */
/*    it under the terms of the GNU General Public License as published by      */
/*    the Free Software Foundation, either version 3 of the License, or         */
/*    (at your option) any later version.                                       */
/*                                                                              */
/*    This program is distributed in the hope that it will be useful,           */
/*    but WITHOUT ANY WARRANTY; without even the implied warranty of            */
/*    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the             */
/*    GNU General Public License for more details.                              */
/*                                                                              */
/*    You should have received a copy of the GNU General Public License         */
/*    along with this program.  If not, see <https://www.gnu.org/licenses/>.    */
/*                                                                              */
/********************************************************************************/

/*
    [References]:
        Kutz et al. (2017). Spectral and Decomposition Tracking for Rendering HeterogeneousVolumes. https://media.disneyanimation.com/uploads/production/publication_asset/158/asset/SpectralAndDecompositionTracking.pdf
*/

float jitter = temporalBlueNoise(gl_FragCoord.xy);

const float aerialPerspectiveMult = 1.0;

#if defined WORLD_OVERWORLD

    // Overworld

    const vec3 sandFogExtinctionCoefficients = vec3(0.24, 0.28, 0.36);
    const vec3 sandFogScatteringCoefficients = vec3(0.80, 0.55, 0.36);

    vec3 airFogAttenuationCoefficients = mix(vec3(airFogExtinctionCoefficient), sandFogExtinctionCoefficients, biome_may_sandstorm);
    vec3 airFogScatteringCoefficients  = mix(vec3(airFogScatteringCoefficient), sandFogScatteringCoefficients, biome_may_sandstorm);

    const float fogAltitude  = FOG_ALTITUDE;
    const float fogThickness = FOG_THICKNESS;
    
    float fogFrequency    = mix(0.7, 1.0, biome_may_sandstorm);
    vec2  fogShapeFactors = mix(vec2(1.5, 0.4), vec2(2.0, 0.4), biome_may_sandstorm);
    float densityFactor   = wetness;
    float densityMult     = mix(0.03, 0.7, biome_may_sandstorm);

#elif defined WORLD_NETHER

    // Nether

    const vec3 airFogAttenuationCoefficients = vec3(0.02, 0.03, 0.30);
    const vec3 airFogScatteringCoefficients  = vec3(0.20, 0.10, 0.06);

    const float fogAltitude     = max(0.0, FOG_ALTITUDE - 63.0);
    const float fogThickness    = FOG_THICKNESS * 2.0;
    const float fogFrequency    = 0.7;
    const vec2  fogShapeFactors = vec2(2.0, 0.7);
    const float densityFactor   = 1.0;
    const float densityMult     = 0.03;

#elif defined WORLD_END

    // End

    float airFogTransitionFactor = sin(frameTimeCounter * 2.0);

    vec3 airFogAttenuationCoefficients = mix(vec3(0.30, 0.20, 0.30), vec3(0.10, 0.05, 0.10), airFogTransitionFactor);
    vec3 airFogScatteringCoefficients  = mix(vec3(0.80, 0.70, 0.80), vec3(1.00, 1.00, 1.00), airFogTransitionFactor);

    const float fogAltitude     = max(0.0, FOG_ALTITUDE - 63.0);
    const float fogThickness    = min(200.0, (FOG_THICKNESS + 40.0) * 2.0);
    const float fogFrequency    = 0.7;
    const vec2  fogShapeFactors = vec2(2.0, 0.7);
    const float densityFactor   = 1.0;
    const float densityMult     = 1.0;

#endif

float fogDensity = saturate(FOG_DENSITY + densityFactor) * 0.4;

uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;
uniform float rcp240;

float calculateAirFogPhase(float cosTheta) {
    float forwardsLobe  = henyeyGreensteinPhase(cosTheta, airFogForwardsLobe);
    float backwardsLobe = henyeyGreensteinPhase(cosTheta,-airFogBackardsLobe);
    float forwardsPeak  = cornetteShanksPhase  (cosTheta, airFogForwardsPeak);

    return mix(mix(forwardsLobe, backwardsLobe, airFogBackScatter), forwardsPeak, airFogPeakWeight);
}

#if AIR_FOG == 2

    //////////////////////////////////////////////////////////
    /*--------------- AIR FOG APPROXIMATION ----------------*/
    //////////////////////////////////////////////////////////

    void computeAirFogApproximation(
        out vec3 scatteringOut,
        out vec3 transmittanceOut,
        vec3 viewPosition,
        float VdotL,
        vec3 directIlluminance,
        vec3 skyIlluminance,
        float skylight
    ) {
        float airmassFog = quinticStep(0.0, far, length(viewPosition.xz)) * fogDensity * densityMult;

        vec3 transmittanceFog = exp(-airFogAttenuationCoefficients * airmassFog * 10.0);

        vec3 scatteringFog  = skyIlluminance    * isotropicPhase * skylight;
             scatteringFog += directIlluminance * calculateAirFogPhase(VdotL);
             scatteringFog *= airFogScatteringCoefficients * ((1.0 - transmittanceFog) / airFogAttenuationCoefficients);

        vec3 scatteringAerial    = vec3(0.0);
        vec3 transmittanceAerial = vec3(1.0);

        #if defined WORLD_OVERWORLD && AERIAL_PERSPECTIVE == 1

            float airmassAerial      = quinticStep(0.0, farPlane, length(viewPosition.xz)) * aerialPerspectiveMult * AERIAL_PERSPECTIVE_DENSITY * AERIAL_PERSPECTIVE_DENSITY_MULTIPLIER;
            vec3  opticalDepthAerial = atmosphereAttenuationCoefficients * vec3(airmassAerial);

            transmittanceAerial = exp(-opticalDepthAerial);

            vec2 phaseAerial = vec2(rayleighPhase(VdotL), kleinNishinaPhase(VdotL, mieAnisotropyFactor));

            vec3 visibleScatteringAerial = saturate((transmittanceAerial - 1.0) / -opticalDepthAerial);

            scatteringAerial  = atmosphereScatteringCoefficients * vec2(phaseAerial * airmassAerial) * visibleScatteringAerial;
            scatteringAerial *= directIlluminance * skyIlluminance * eyeBrightness.y * rcp240;

        #endif
        
        scatteringOut    = scatteringFog    + scatteringAerial;
        transmittanceOut = transmittanceFog * transmittanceAerial;
    }

#elif AIR_FOG == 1

    //////////////////////////////////////////////////////////
    /*----------------- AIR FOG RAYMARCHED -----------------*/
    //////////////////////////////////////////////////////////

    uniform sampler3D depthtex2;

    float getAirFogDensity(vec3 position) {
        
        if (clamp(position.y, fogAltitude, fogAltitude + fogThickness) != position.y) {
            return 0.0;
        }

        float altitude   = (position.y - fogAltitude) / fogThickness;
        float shapeAlter = remap(altitude, 0.0, 0.2, 0.0, 1.0) * remap(altitude, 0.9, 1.0, 1.0, 0.0);

        #if defined WORLD_END

            // Rotating cloud centered at the origin (0,0,0)
        
            float movementSpeed = frameTimeCounter * 10.0;

            position.y -= 60.0;
            position.xz = -position.xz;
            position    = rotate(position, vec3(0.0, 1.0, 0.0), starVector);
            position    = rotate(position, vec3(0.0, 1.0, 0.0), movementSpeed);
            position.xz = -position.xz;
            position.y -= movementSpeed;

        #endif

        #if defined WORLD_NETHER

            //fogShapeFactors = mix(vec2(2.5, 0.6), fogShapeFactors, sqrt(quinticStep(0.0, 1.0, min(125.0, position.y) / 125.0)));

        #endif
        
        vec4  shapeTex   = texture(depthtex2, position * FOG_SHAPE_SCALE * 1e-4);
        float shapeNoise = remap(shapeTex.r, -(1.0 - (shapeTex.g * 0.625 + shapeTex.b * 0.25 + shapeTex.a * 0.125)), 1.0, 0.0, 1.0);
              shapeNoise = (shapeNoise * shapeAlter - (2.0 * shapeAlter * altitude * 0.5 + 0.5)) * fogShapeFactors.x - fogShapeFactors.y;

        #if defined WORLD_OVERWORLD

            shapeNoise *= smoothstep(0.0, 1.0, exp(-abs(position.y - fogAltitude) * 0.03));

        #elif defined WORLD_NETHER

            //fogDensity *= mix(1.2, 1.0, sqrt(quinticStep(0.0, 1.0, min(125.0, position.y) / 125.0)));

        #elif defined WORLD_END

            // End cloud ring shape

            float innerRadius    = 30.0;
            float outerRingStart = 70.0;
            float outerRingEnd   = 160.0;

            float distanceFromCenter = length(position.xz);

            float fogFalloff = quinticStep(innerRadius, outerRingStart, distanceFromCenter) * 
                               pow2(quinticStep(outerRingEnd, outerRingStart, distanceFromCenter)) * 
                               exp(-rcp(distanceFromCenter));

            shapeNoise *= fogFalloff;

        #endif
        
        return saturate(shapeNoise) * fogDensity * densityMult;
    }

    vec2 intersectFogVolume(vec3 rayDirection) {
        
        float rcpDirectionY = 1.0 / rayDirection.y;

        float volumeStart = (fogAltitude                - eyeAltitude) * rcpDirectionY;
        float volumeEnd   = (fogAltitude + fogThickness - eyeAltitude) * rcpDirectionY;

        if (rayDirection.y < 0.0) {
            float tmp = volumeStart;

            volumeStart = volumeEnd;
            volumeEnd   = tmp;
        }

        if (volumeEnd < 0.0) { return vec2(-1.0); }

        return vec2(max0(volumeStart), volumeEnd);
    }

    void computeVolumetricAirFog(
        inout vec3 scatteringOut,
        inout vec3 transmittanceOut,
        vec3 startPosition,
        vec3 endPosition,
        vec3 viewPosition,
        float VdotL,
        vec3 directIlluminance,
        vec3 skyIlluminance,
        bool sky
    ) {
        #if (defined WORLD_NETHER && NETHER_FOG == 0) || (defined WORLD_END && END_FOG == 0)
            return;
        #endif

        vec3 scatteringSun = vec3(0.0);
        vec3 scatteringSky = vec3(0.0);

        const float minDensity = 0.01;

        // Ray marching setup

        vec3 rayDirection = endPosition - startPosition;

        float rayLength    = lengthSqr(rayDirection);
        float rcpRayLength = inversesqrt(rayLength);
        
        rayLength    *= rcpRayLength;
        rayDirection *= rcpRayLength;

        if (rayLength < EPS) { return; }

        vec3 shadowStartPosition = worldToShadowClip(startPosition);
        vec3 shadowDirection     = mat3(shadowModelView) * rayDirection * diagonal3(shadowProjection);

        //////////////////////////////////////////////////////////
        /*------------------ AIR FOG TRACING -------------------*/
        //////////////////////////////////////////////////////////

        // Intersecting the fog volume
        vec2 distsToVolume = intersectFogVolume(rayDirection);

        if (distsToVolume.y > 0.0 && fogDensity > minDensity) {

            // Calculating the distance travelled inside the fog volume per step
            float fogRayLength = sky ? distsToVolume.y : rayLength;
                  fogRayLength = clamp(fogRayLength - distsToVolume.x, 0.0, farPlane);

            int fogStepCount = int(floor(float(AIR_FOG_MIN_SCATTERING_STEPS) + AIR_FOG_SCATTERING_STEPS_GROWTH * fogRayLength));
                fogStepCount = min(fogStepCount, AIR_FOG_MAX_SCATTERING_STEPS);

            float fogStepSize = 1.0 / float(fogStepCount);

            fogRayLength *= fogStepSize;
            
            vec3 fogIncrement = rayDirection * fogRayLength;

            vec3 fogRayPosition  = startPosition + rayDirection * (distsToVolume.x + fogRayLength * jitter);
                 fogRayPosition += cameraPosition;

            vec3 fogShadowIncrement = (worldToShadowClip(endPosition) - shadowStartPosition) * fogStepSize;
            vec3 fogShadowPosition  = shadowStartPosition + shadowDirection * (distsToVolume.x + fogRayLength * jitter);

            // Fog phase
            float phaseFog = calculateAirFogPhase(VdotL);

            for (int i = 0; i < fogStepCount && maxOf(transmittanceOut) > EPS; i++) {

                // Shadows sampling

                vec3 shadow = vec3(1.0);

                #if defined WORLD_OVERWORLD
                
                    shadow = getShadowColor(shadowClipToShadowScreen(fogShadowPosition));

                    #if CLOUDS_SHADOWS == 1 && CLOUDS_LAYER0_ENABLED == 1
                        shadow *= getCloudsShadows(fogRayPosition);
                    #endif

                #endif

                // Air fog

                float distanceFalloffFog = linearStep(0.0, 1.0, farPlane / length(fogRayPosition.xz - cameraPosition.xz));

                float densityFog = getAirFogDensity(fogRayPosition) * distanceFalloffFog;

                if (densityFog > minDensity) {

                    float airmassFog      = densityFog * fogRayLength;
                    vec3  opticalDepthFog = airFogAttenuationCoefficients * airmassFog;

                    vec3 stepTransmittanceFog = exp(-opticalDepthFog);
                    vec3 visibleScatteringFog = transmittanceOut * saturate((stepTransmittanceFog - 1.0) / -opticalDepthFog);

                    scatteringSun += airFogScatteringCoefficients * airmassFog * phaseFog       * visibleScatteringFog * shadow;
                    scatteringSky += airFogScatteringCoefficients * airmassFog * isotropicPhase * visibleScatteringFog;

                    transmittanceOut *= stepTransmittanceFog;

                }

                // Incrementing rays
                fogRayPosition    += fogIncrement;
                fogShadowPosition += fogShadowIncrement;
            }

        }

        //////////////////////////////////////////////////////////
        /*------------- AERIAL PERSPECTIVE TRACING -------------*/
        //////////////////////////////////////////////////////////

        #if defined WORLD_OVERWORLD && AERIAL_PERSPECTIVE == 1

            const float aerialStepSize = 1.0 / AERIAL_PERSPECTIVE_SCATTERING_STEPS;

            float aerialRayLength  = mix(rayLength, rayLength * AERIAL_PERSPECTIVE_DISTANCE_MULTIPLIER, saturate(rayLength / farPlane) * float(!sky));
                  aerialRayLength *= aerialStepSize;

            vec3 aerialIncrement = rayDirection * aerialRayLength;

            vec3 aerialRayPosition  = startPosition + aerialIncrement * jitter;
                 aerialRayPosition += cameraPosition;

            vec3 aerialShadowIncrement = (worldToShadowClip(endPosition) - shadowStartPosition) * aerialStepSize;
            vec3 aerialShadowPosition  = shadowStartPosition + aerialShadowIncrement * jitter;

            // Aerial perspective phase
            vec2 phaseAerial = vec2(rayleighPhase(VdotL), kleinNishinaPhase(VdotL, mieAnisotropyFactor));

            for (int i = 0; i < AERIAL_PERSPECTIVE_SCATTERING_STEPS && maxOf(transmittanceOut) > EPS; i++) {

                // Shadows sampling

                vec3 shadow = getShadowColor(shadowClipToShadowScreen(aerialShadowPosition));

                #if CLOUDS_SHADOWS == 1 && CLOUDS_LAYER0_ENABLED == 1
                    shadow *= getCloudsShadows(aerialShadowPosition);
                #endif

                // Aerial perspective

                float airmassAerial      = aerialRayLength * AERIAL_PERSPECTIVE_DENSITY;
                vec3  opticalDepthAerial = atmosphereAttenuationCoefficients * vec3(airmassAerial);

                vec3 stepTransmittanceAerial = exp(-opticalDepthAerial);
                vec3 visibleScatteringAerial = transmittanceOut * saturate((stepTransmittanceAerial - 1.0) / -opticalDepthAerial);

                scatteringSun += atmosphereScatteringCoefficients * vec2(phaseAerial    * airmassAerial) * visibleScatteringAerial * shadow;
                scatteringSky += atmosphereScatteringCoefficients * vec2(isotropicPhase * airmassAerial) * visibleScatteringAerial;

                transmittanceOut *= stepTransmittanceAerial;

                // Incrementing rays
                aerialRayPosition    += aerialIncrement;
                aerialShadowPosition += aerialShadowIncrement;
            }

        #endif

        //////////////////////////////////////////////////////////
        /*------------- FOG SCATTERING EVALUATION --------------*/
        //////////////////////////////////////////////////////////

        #if defined WORLD_OVERWORLD
            scatteringSky *= eyeBrightness.y * rcp240;
        #endif

        scatteringOut += scatteringSun * directIlluminance
                       + scatteringSky * skyIlluminance;
    }

#endif

#if WATER_FOG == 0

    //////////////////////////////////////////////////////////
    /*-------------- WATER FOG APPROXIMATION ---------------*/
    //////////////////////////////////////////////////////////

    void computeWaterFogApproximation(
        out vec3 scatteringOut,
        out vec3 transmittanceOut,
        vec3 startPosition,
        vec3 endPosition,
        float VdotL,
        vec3 directIlluminance,
        vec3 skyIlluminance,
        float skylight
    ) {
        transmittanceOut = exp(-waterAbsorptionCoefficients * distance(startPosition, endPosition));

        scatteringOut  = skyIlluminance    * isotropicPhase * skylight;
        scatteringOut += directIlluminance * cornetteShanksPhase(VdotL, waterAnisotropyFactor);
        scatteringOut *= waterScatteringCoefficients * (1.0 - transmittanceOut) / waterAbsorptionCoefficients;
    }

#else

    //////////////////////////////////////////////////////////
    /*---------------- WATER FOG RAYMARCHED ----------------*/
    //////////////////////////////////////////////////////////

    void computeVolumetricWaterFog(
        out vec3 scatteringOut,
        out vec3 transmittanceOut,
        vec3 startPosition,
        vec3 endPosition,
        float VdotL,
        vec3 directIlluminance,
        vec3 skyIlluminance,
        float skylight,
        bool sky
    ) {
        // Ray marching setup

        const float rcpSteps = 1.0 / WATER_FOG_STEPS;

        vec3  rayVector = endPosition - startPosition;
        float rayLength = length(rayVector);

        if (rayLength < EPS) { return; }

        vec3 worldDirection = rayVector / rayLength;

        vec3 shadowStartPosition = worldToShadowClip(startPosition);
        vec3 shadowDirection     = mat3(shadowModelView) * worldDirection * diagonal3(shadowProjection);

        // Analytical transmittance evaluation (water is a homogeneous medium)
        vec3 transmittance = exp(-waterExtinctionCoefficients * rayLength);

        // CDF over the ray's length for interaction with a water particle (CDF(rayLength) = 1.0 - transmittance)
        vec3  interactionProbability    = 1.0 - transmittance;
	    float minInteractionProbability = minOf(interactionProbability);

        float dominantExtinction = minOf(waterExtinctionCoefficients);

        vec3 scatteringSun = vec3(0.0);
        vec3 scatteringSky = vec3(0.0); 

        for (int i = 0; i < WATER_FOG_STEPS; i++) {

            float rng = (i + jitter) * rcpSteps;

            // Inverting the CDF into a distance value for this iteration/step
            float stepSize = -log(1.0 - minInteractionProbability * rng) / dominantExtinction;

            // Spectral MIS weighting to correct for sampling the step size from a scalar distribution to integrate for three RGB channels
            float sampledPDF = dominantExtinction          * exp(-dominantExtinction          * stepSize) / minInteractionProbability;
            vec3  desiredPDF = waterExtinctionCoefficients * exp(-waterExtinctionCoefficients * stepSize) / interactionProbability;

            vec3 misWeight = desiredPDF / sampledPDF;

            // Shadows sampling
            vec3 shadowPosition = shadowStartPosition + shadowDirection * stepSize;

            vec3 shadowScreenPosition = shadowClipToShadowScreen(shadowPosition);

            float shadowDepth0 = texture(shadowtex0, shadowScreenPosition.xy).r;
            vec3  shadow       = getShadowColor(shadowScreenPosition)
                               + getShadowCaustics(shadowScreenPosition);

            #if CLOUDS_SHADOWS == 1 && CLOUDS_LAYER0_ENABLED == 1

                shadow *= getCloudsShadows(startPosition + worldDirection * stepSize);

            #endif

            // Linearized distance travelled through water
            float distanceThroughWater = max0(shadowScreenPosition.z - shadowDepth0) * -shadowProjectionInverse[2].z * RCP_SHADOWS_DEPTH_STRETCH * 2.0;

            scatteringSun += misWeight * shadow * exp(-waterAbsorptionCoefficients * distanceThroughWater);
            scatteringSky += misWeight;
        }

        vec3 scatteringAlbedo = saturate(waterScatteringCoefficients / waterExtinctionCoefficients);

        // Multiple scattering approximation provided by Jessie
        vec3 multipleScatteringFactor = scatteringAlbedo * 0.84;

        const int phaseSampleCount = 4;

        float phaseMultiple = 0.0;
        float anisotropy    = waterAnisotropyFactor;

        // Fake multi-lobe scattering by averaging multiple phase terms
        for (int i = 0; i < phaseSampleCount; i++) {
            phaseMultiple += cornetteShanksPhase(VdotL, anisotropy);
            anisotropy    *= 0.5;
        }
        
        phaseMultiple /= phaseSampleCount;

        float eyeSkylight      = pow2(saturate(eyeBrightnessSmooth.y * rcp240));
        float adaptiveSkylight = mix(eyeSkylight, skylight, isEyeInWater == 1 ? maxOf(transmittance) : 1.0);

        // Integral evaluation
        scatteringOut  = scatteringSun * directIlluminance * phaseMultiple
                       + scatteringSky * skyIlluminance    * isotropicPhase * adaptiveSkylight;

        scatteringOut *= waterScatteringCoefficients * (1.0 - transmittance) * rcpSteps;
        scatteringOut *= multipleScatteringFactor / (1.0 - multipleScatteringFactor);

        transmittanceOut = transmittance;
    }

#endif
