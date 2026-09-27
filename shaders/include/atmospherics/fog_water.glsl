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
        Frisvad et al. (2007). Computing the Scattering Properties of Participating Media Using Lorenz-Mie Theory. https://dl.acm.org/doi/abs/10.1145/1275808.1276452
        Kutz et al. (2017). Spectral and Decomposition Tracking for Rendering Heterogeneous Volumes. https://media.disneyanimation.com/uploads/production/publication_asset/158/asset/SpectralAndDecompositionTracking.pdf
*/

#if WATER_FOG == 1

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
        float skyLight
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

                shadow *= getCloudsShadows(startPosition + worldDirection * stepSize - cameraPosition);

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
