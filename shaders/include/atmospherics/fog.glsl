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

uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;
uniform float rcp240;

float jitter = temporalBlueNoise(SCREEN_COORDS);

#if defined WORLD_OVERWORLD

    // Overworld

    const vec3 mistFogAbsorptionCoefficients = SRGB_TO_WORKING_SPACE_ALBEDO(vec3(MIST_ABSORPTION_R, MIST_ABSORPTION_G, MIST_ABSORPTION_B) * 0.01);
    const vec3 mistFogScatteringCoefficients = SRGB_TO_WORKING_SPACE_ALBEDO(vec3(MIST_SCATTERING_R, MIST_SCATTERING_G, MIST_SCATTERING_B) * 0.01);

    const vec3 sandFogAbsorptionCoefficients = SRGB_TO_WORKING_SPACE_ALBEDO(vec3(SANDSTORMS_ABSORPTION_R, SANDSTORMS_ABSORPTION_G, SANDSTORMS_ABSORPTION_B) * 0.01);
    const vec3 sandFogScatteringCoefficients = SRGB_TO_WORKING_SPACE_ALBEDO(vec3(SANDSTORMS_SCATTERING_R, SANDSTORMS_SCATTERING_G, SANDSTORMS_SCATTERING_B) * 0.01);

    vec3 airFogAbsorptionCoefficients = mix(mistFogAbsorptionCoefficients, sandFogAbsorptionCoefficients, biome_may_sandstorm);
    vec3 airFogScatteringCoefficients = mix(mistFogScatteringCoefficients, sandFogScatteringCoefficients, biome_may_sandstorm);

    const float fogAltitude  = FOG_ALTITUDE;
    const float fogThickness = FOG_THICKNESS;

    vec2  fogShapeFactors = mix(vec2(1.5, 0.4), vec2(2.0, 0.4), biome_may_sandstorm);
    float densityFactor   = wetness;
    float densityMult     = mix(0.03, 0.1, biome_may_sandstorm);

#elif defined WORLD_NETHER

    // Nether

    const vec3 airFogAbsorptionCoefficients = SRGB_TO_WORKING_SPACE_ALBEDO(vec3(NETHER_ABSORPTION_R, NETHER_ABSORPTION_G, NETHER_ABSORPTION_B) * 0.01);
    const vec3 airFogScatteringCoefficients = SRGB_TO_WORKING_SPACE_ALBEDO(vec3(NETHER_SCATTERING_R, NETHER_SCATTERING_G, NETHER_SCATTERING_B) * 0.01);

    const float fogAltitude     = max(0.0, FOG_ALTITUDE - SEA_LEVEL);
    const float fogThickness    = FOG_THICKNESS * 2.0;
    const vec2  fogShapeFactors = vec2(2.0, 0.7);
    const float densityFactor   = 0.2;
    const float densityMult     = 0.05;

#elif defined WORLD_END

    // End

    const vec3 endFogAbsorptionCoefficients = SRGB_TO_WORKING_SPACE_ALBEDO(vec3(END_ABSORPTION_R, END_ABSORPTION_G, END_ABSORPTION_B) * 0.01);
    const vec3 endFogScatteringCoefficients = SRGB_TO_WORKING_SPACE_ALBEDO(vec3(END_SCATTERING_R, END_SCATTERING_G, END_SCATTERING_B) * 0.01);

    const vec3 endFogFlashAbsorptionCoefficients = SRGB_TO_WORKING_SPACE_ALBEDO(vec3(0.10, 0.05, 0.10));
    const vec3 endFogFlashScatteringCoefficients = SRGB_TO_WORKING_SPACE_ALBEDO(vec3(1.00, 1.00, 1.00));

    float airFogTransitionFactor = sin(frameTimeCounter * 2.0);

    vec3 airFogAbsorptionCoefficients = mix(endFogAbsorptionCoefficients, endFogFlashAbsorptionCoefficients, airFogTransitionFactor);
    vec3 airFogScatteringCoefficients = mix(endFogScatteringCoefficients, endFogFlashScatteringCoefficients, airFogTransitionFactor);

    const float fogAltitude     = max(0.0, FOG_ALTITUDE - 100.0);
    const float fogThickness    = min(200.0, (FOG_THICKNESS + 40.0) * 2.0);
    const vec2  fogShapeFactors = vec2(2.0, 0.7);
    const float densityFactor   = 1.0;
    const float densityMult     = 0.1;

#endif

float fogDensity = saturate(FOG_DENSITY + densityFactor);


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
        vec3 scenePosition,
        float VdotL,
        vec3 directIlluminance,
        vec3 skyIlluminance,
        float skyLight,
        bool sky
    ) {
        float eyeSkylight = pow2(saturate(eyeBrightnessSmooth.y * rcp240));

        float density = quinticStep(0.0, 1.0, saturate(length(scenePosition) / farPlane));

        float airmassFog = density * 0.5 * farPlane * fogDensity * densityMult;

        vec3 transmittanceFog = exp(-airFogAbsorptionCoefficients * airmassFog);

        vec3 scatteringFog  = directIlluminance * calculateAirFogPhase(VdotL);
             scatteringFog += skyIlluminance    * isotropicPhase * eyeSkylight;
             scatteringFog *= airFogScatteringCoefficients * ((1.0 - transmittanceFog) / airFogAbsorptionCoefficients);

        vec3 scatteringAerial    = vec3(0.0);
        vec3 transmittanceAerial = vec3(1.0);

        #if defined WORLD_OVERWORLD && AERIAL_PERSPECTIVE == 1

            float airmassAerial  = density * farPlane * AERIAL_PERSPECTIVE_DENSITY * AERIAL_PERSPECTIVE_DISTANCE_MULTIPLIER;
                  airmassAerial *= (sky ? 0.1 : 1.0);

            vec3 opticalDepthAerial = atmosphereAttenuationCoefficients * vec3(airmassAerial);

            transmittanceAerial = exp(-opticalDepthAerial);

            vec2 phaseAerial = vec2(rayleighPhase(VdotL), kleinNishinaPhase(VdotL, mieAnisotropyFactor));

            vec3 visibleScatteringAerial = saturate((transmittanceAerial - 1.0) / -opticalDepthAerial);

            scatteringAerial += atmosphereScatteringCoefficients * vec2(phaseAerial    * airmassAerial) * visibleScatteringAerial * directIlluminance;
            scatteringAerial += atmosphereScatteringCoefficients * vec2(isotropicPhase * airmassAerial) * visibleScatteringAerial * skyIlluminance * eyeSkylight;

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
        float VdotL,
        vec3 directIlluminance,
        vec3 skyIlluminance,
        bool sky
    ) {
        #if (defined WORLD_NETHER && NETHER_FOG == 0) || (defined WORLD_END && END_FOG == 0)
            return;
        #endif

        // Ray marching setup

        vec3 rayDirection = endPosition - startPosition;

        float rayLength    = lengthSqr(rayDirection);
        float rcpRayLength = inversesqrt(rayLength);
        
        rayLength    *= rcpRayLength;
        rayDirection *= rcpRayLength;

        if (rayLength < EPS) { return; }

        vec3 shadowStartPosition = worldToShadowClip(startPosition);
        vec3 shadowDirection     = mat3(shadowModelView) * rayDirection * diagonal3(shadowProjection);

        const float minDensity = 1e-4;

        //////////////////////////////////////////////////////////
        /*----------------- GROUND FOG TRACING -----------------*/
        //////////////////////////////////////////////////////////

        vec3 scatteringSunGround = vec3(0.0);
        vec3 scatteringSkyGround = vec3(0.0);

        vec3 transmittanceGround = vec3(1.0);

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

            for (int i = 0; i < fogStepCount && maxOf(transmittanceGround) > EPS; i++) {

                // Shadows sampling

                vec3 shadow = vec3(1.0);

                #if defined WORLD_OVERWORLD
                
                    shadow = getShadowColor(shadowClipToShadowScreen(fogShadowPosition));

                    #if CLOUDS_SHADOWS == 1 && CLOUDS_LAYER0_ENABLED == 1
                        shadow *= getCloudsShadows(fogRayPosition);
                    #endif

                #endif

                // Air fog

                float densityFog = getAirFogDensity(fogRayPosition);

                if (densityFog > minDensity) {

                    float airmassFog      = densityFog * mix(fogRayLength, 0.0, length(startPosition) / farPlane);
                    vec3  opticalDepthFog = airFogAbsorptionCoefficients * airmassFog;

                    vec3 stepTransmittanceFog = exp(-opticalDepthFog);
                    vec3 visibleScatteringFog = transmittanceGround * saturate((stepTransmittanceFog - 1.0) / -opticalDepthFog);

                    scatteringSunGround += airFogScatteringCoefficients * airmassFog * phaseFog       * visibleScatteringFog * shadow;
                    scatteringSkyGround += airFogScatteringCoefficients * airmassFog * isotropicPhase * visibleScatteringFog;

                    transmittanceGround *= stepTransmittanceFog;

                }

                // Incrementing rays
                fogRayPosition    += fogIncrement;
                fogShadowPosition += fogShadowIncrement;
            }
        }

        //////////////////////////////////////////////////////////
        /*------------- AERIAL PERSPECTIVE TRACING -------------*/
        //////////////////////////////////////////////////////////

        vec3 scatteringSunAerial = vec3(0.0);
        vec3 scatteringSkyAerial = vec3(0.0);

        vec3 transmittanceAerial = vec3(1.0);

        #if defined WORLD_OVERWORLD && AERIAL_PERSPECTIVE == 1

            const float aerialStepSize = 1.0 / AERIAL_PERSPECTIVE_SCATTERING_STEPS;

            float aerialRayLength  = mix(rayLength, rayLength * AERIAL_PERSPECTIVE_DISTANCE_MULTIPLIER, saturate(rayLength / farPlane) * float(!sky));
                  aerialRayLength *= aerialStepSize;
            
            #if defined VOXY

                if (sky) {
                    aerialRayLength *= 0.25; // Required because Voxy is a pain in the ass
                }

            #endif

            vec3 aerialIncrement = rayDirection * aerialRayLength;

            vec3 aerialRayPosition  = startPosition + aerialIncrement * jitter;
                 aerialRayPosition += cameraPosition;

            vec3 aerialShadowIncrement = (worldToShadowClip(endPosition) - shadowStartPosition) * aerialStepSize;
            vec3 aerialShadowPosition  = shadowStartPosition + aerialShadowIncrement * jitter;

            // Aerial perspective phase
            vec2 phaseAerial = vec2(rayleighPhase(VdotL), kleinNishinaPhase(VdotL, mieAnisotropyFactor));

            float airmassAerial      = aerialRayLength * AERIAL_PERSPECTIVE_DENSITY;
            vec3  opticalDepthAerial = atmosphereAttenuationCoefficients * vec3(airmassAerial);

            vec3 stepTransmittanceAerial = exp(-opticalDepthAerial);

            vec3 integratedStepTransmittanceAerial = saturate((stepTransmittanceAerial - 1.0) / -opticalDepthAerial);

            for (int i = 0; i < AERIAL_PERSPECTIVE_SCATTERING_STEPS && maxOf(transmittanceAerial) > EPS; i++) {

                // Shadows sampling

                vec3 shadow = vec3(1.0);
                
                #if defined WORLD_OVERWORLD
                
                    shadow = getShadowColor(shadowClipToShadowScreen(aerialShadowPosition));

                    #if CLOUDS_SHADOWS == 1 && CLOUDS_LAYER0_ENABLED == 1
                        shadow *= getCloudsShadows(aerialRayPosition);
                    #endif

                #endif

                // Aerial perspective

                vec3 visibleScatteringAerial = transmittanceAerial * integratedStepTransmittanceAerial;

                scatteringSunAerial += atmosphereScatteringCoefficients * vec2(phaseAerial    * airmassAerial) * visibleScatteringAerial * shadow;
                scatteringSkyAerial += atmosphereScatteringCoefficients * vec2(isotropicPhase * airmassAerial) * visibleScatteringAerial;

                transmittanceAerial *= stepTransmittanceAerial;

                // Incrementing rays
                aerialRayPosition    += aerialIncrement;
                aerialShadowPosition += aerialShadowIncrement;
            }

        #endif

        //////////////////////////////////////////////////////////
        /*------------- FOG SCATTERING EVALUATION --------------*/
        //////////////////////////////////////////////////////////

        vec3 scatteringSun, scatteringSky;

        if (distsToVolume.x > 0.0) {

            // Ground fog is closer to the camera than aerial perspective fog

            scatteringSun = scatteringSunAerial + scatteringSunGround * transmittanceAerial;
            scatteringSky = scatteringSkyAerial + scatteringSkyGround * transmittanceAerial;

        } else {

            // Aerial perspective fog is closer to the camera than ground fog

            scatteringSun = scatteringSunGround + scatteringSunAerial * transmittanceGround;
            scatteringSky = scatteringSkyGround + scatteringSkyAerial * transmittanceGround;

        }

        #if defined WORLD_OVERWORLD
            scatteringSky *= eyeBrightness.y * rcp240;
        #endif

        scatteringOut += scatteringSun * directIlluminance
                       + scatteringSky * skyIlluminance;
        
        transmittanceOut = transmittanceGround * transmittanceAerial;
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
        float skyLight
    ) {
        transmittanceOut = exp(-waterAbsorptionCoefficients * distance(startPosition, endPosition));

        scatteringOut  = skyIlluminance    * isotropicPhase * skyLight;
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
        float skyLight,
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

            vec3 shadowScreenPosition = shadowClipToShadowScreen(shadowStartPosition + shadowDirection * stepSize);

            float shadowDepth0 = texture(shadowtex0, shadowScreenPosition.xy).r;
            vec3  shadow       = getShadowColor(shadowScreenPosition)
                               + getShadowCaustics(shadowScreenPosition);

            #if defined WORLD_OVERWORLD && CLOUDS_SHADOWS == 1 && CLOUDS_LAYER0_ENABLED == 1

                shadow *= getCloudsShadows(startPosition + worldDirection * stepSize);

            #endif

            // Linearized distance travelled through water
            float distanceThroughWater = max0(shadowScreenPosition.z - shadowDepth0) * -shadowProjectionInverse[2].z * RCP_SHADOWS_DEPTH_STRETCH * 2.0;

            scatteringSun += misWeight * shadow * exp(-waterExtinctionCoefficients * distanceThroughWater);
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
        float adaptiveSkylight = mix(eyeSkylight, skyLight, isEyeInWater == 1 ? maxOf(transmittance) : 1.0);

        // Integral evaluation
        scatteringOut  = scatteringSun * directIlluminance * phaseMultiple
                       + scatteringSky * skyIlluminance    * isotropicPhase * adaptiveSkylight;

        scatteringOut *= waterScatteringCoefficients * (1.0 - transmittance) * rcpSteps;
        scatteringOut *= multipleScatteringFactor / (1.0 - multipleScatteringFactor);

        transmittanceOut = transmittance;
    }

#endif
