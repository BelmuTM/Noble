/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* 
    SOURCES / CREDITS:
    EA:                        https://media.contentapi.ea.com/content/dam/eacom/frostbite/files/s2016-pbs-frostbite-sky-clouds-new.pdf
    Rurik Högfeldt:            https://odr.chalmers.se/bitstream/20.500.12380/241770/1/241770.pdf
    Fredrik Häggström:         http://www.diva-portal.org/smash/get/diva2:1223894/FULLTEXT01.pdf
    LVutner:                   https://www.shadertoy.com/view/stScDz - LVutner#5199
    Sony Pictures Imageworks:  http://magnuswrenninge.com/wp-content/uploads/2010/03/Wrenninge-OzTheGreatAndVolumetric.pdf
    Guerrilla - SIGGRAPH 2015: https://www.guerrilla-games.com/media/News/Files/The-Real-time-Volumetric-Cloudscapes-of-Horizon-Zero-Dawn.pdf

    SPECIAL THANKS:
    SixthSurge (noise generator for clouds shape and help with lighting): https://github.com/sixthsurge - SixthSurge#3922
*/

float heightAlter(float altitude, float weatherMap) {
    float stopHeight = clamp01(weatherMap + 0.12);

    float heightAlter  = clamp01(remap(altitude, 0.0, 0.07, 0.0, 1.0));
          heightAlter *= clamp01(remap(altitude, stopHeight * 0.2, stopHeight, 1.0, 0.0));
    return heightAlter;
}

float densityAlter(float altitude, float weatherMap) {
    float densityAlter  = altitude * clamp01(remap(altitude, 0.0, 0.2, 0.0, 1.0));
          densityAlter *= clamp01(remap(altitude, 0.9, 1.0, 1.0, 0.0));
          densityAlter *= weatherMap * 2.0;
    return densityAlter;
}

float getCloudsDensity(vec3 position) {
    float altitude     = (position.y - innerCloudRad) * rcp(CLOUDS_THICKNESS);
    vec2 windDirection = WIND_SPEED * sincos(windAngleRad);

    #if ACCUMULATION_VELOCITY_WEIGHT == 0
        position.xz += windDirection * frameTimeCounter;
    #endif

    vec3 position1 = position * 2e-4;
    vec3 position0 = position * 2e-5;

    float globalCoverage = mix(CLOUDS_COVERAGE, 1.0, wetness);

    vec2 weatherNoise = vec2(FBM(position.xz * 8e-4, 2) * 0.5 + 0.5, texture(colortex7, position1.xz).r);
    float weatherMap  = max(weatherNoise.r, clamp01(globalCoverage - 0.5) * weatherNoise.g * 2.0);

    float shapeAlter   = heightAlter(altitude,  weatherMap);
    float densityAlter = densityAlter(altitude, weatherMap);

    vec3 curlTex = texture(colortex14, position * 6e-5).rgb * 2.0 - 1.0;
    position1   += curlTex * CLOUDS_SWIRL;

    vec4 shapeTex     = texture(depthtex2,  position * 4e-4);
    vec3 detailTex    = texture(colortex13, position * 3e-4).rgb;
    vec3 blueNoiseTex = texelFetch(noisetex, ivec2(mod(position.xz * viewSize, noiseRes)), 0).rgb;

    detailTex = mix(detailTex, vec3(1.0), blueNoiseTex);

    float shapeNoise = remap(shapeTex.r, (shapeTex.g * 0.625 + shapeTex.b * 0.25 + shapeTex.a * 0.125) - 1.0, 1.0, 0.0, 1.0);
          shapeNoise = clamp01(remap(shapeNoise * shapeAlter, 1.0 - globalCoverage * weatherMap, 1.0, 0.0, 1.0));

    float detailNoise  = detailTex.r * 0.625 + detailTex.g * 0.25 + detailTex.b * 0.125;
          detailNoise  = mix(detailNoise, 1.0 - detailNoise, clamp01(altitude * 5.0));
          detailNoise *= (0.35 * exp(-globalCoverage * 0.75));

    return clamp01(remap(shapeNoise, detailNoise, 1.0, 0.0, 1.0)) * densityAlter;
}

float getCloudsOpticalDepth(vec3 rayPos, vec3 lightDir, int stepCount) {
    float stepLength = 23.0, opticalDepth = 0.0;

    for(int i = 0; i < stepCount; i++, rayPos += lightDir * stepLength) {
        if(clamp(rayPos.y, innerCloudRad, outerCloudRad) != rayPos.y) continue;

        opticalDepth += getCloudsDensity(rayPos) * stepLength;
        stepLength   *= 1.5;

        if(opticalDepth < EPS) continue;
    }
    return opticalDepth;
}

float getCloudsPhase(float cosTheta, vec3 anisotropyFactors) {
    float forwardsLobe  = cornetteShanksPhase(cosTheta, anisotropyFactors.x);
    float backwardsLobe = cornetteShanksPhase(cosTheta,-anisotropyFactors.y);
    float forwardsPeak  = cornetteShanksPhase(cosTheta, anisotropyFactors.z);

    return mix(mix(forwardsLobe, backwardsLobe, cloudsBackScatter), forwardsPeak, cloudsPeakWeight);
}

vec4 cloudsScattering(vec3 rayDir, out float distToCloud, vec3 directIlluminance, vec3 skyIlluminance) {

    vec2 dists = intersectSphericalShell(atmosRayPos, rayDir, innerCloudRad, outerCloudRad);
    if(dists.y < 0.0) return vec4(0.0, 0.0, 0.0, 1.0);

    float stepLength = (dists.y - dists.x) * rcp(CLOUDS_SCATTERING_STEPS);
    vec3 increment   = rayDir * stepLength;
    vec3 rayPos      = atmosRayPos + rayDir * (dists.x + stepLength * randF());

    float VdotL        = dot(rayDir, sceneShadowDir);
    const vec3 up      = vec3(0.0, 1.0, 0.0);
    float bouncedLight = abs(dot(rayDir, -up)) * RCP_PI * 0.6 * isotropicPhase;

    vec2 scattering = vec2(0.0);
    float transmittance = 1.0, depthWeight = 0.0, depthSum = 0.0;
    
    for(int i = 0; i < CLOUDS_SCATTERING_STEPS; i++, rayPos += increment) {
        if(transmittance <= cloudsTransmitThreshold) break;

        float density = getCloudsDensity(rayPos);
        if(density < EPS) continue;

        depthSum    += distance(atmosRayPos, rayPos) * density; 
        depthWeight += density;

        float stepOpticalDepth  = cloudsExtinctionCoeff * density * stepLength;
        float stepTransmittance = exp(-stepOpticalDepth);

        float directOpticalDepth = getCloudsOpticalDepth(rayPos, sceneShadowDir, 8);
        float skyOpticalDepth    = getCloudsOpticalDepth(rayPos, up,             6);
        float groundOpticalDepth = getCloudsOpticalDepth(rayPos,-up,             3);

        // Beer's-Powder effect from "The Real-time Volumetric Cloudscapes of Horizon: Zero Dawn" (see sources above)
	    float powder    = 8.0 * (1.0 - 0.97 * exp(-2.0 * density));
	    float powderSun = mix(powder, 1.0, VdotL * 0.5 + 0.5);
        float powderSky = mix(powder, 1.0, dot(rayDir, up) * 0.5 + 0.5);

        vec3 anisotropyFactors = pow(vec3(cloudsForwardsLobe, cloudsBackardsLobe, cloudsForwardsPeak), vec3(directOpticalDepth + 1.0));
        float extinctionCoeff  = cloudsExtinctionCoeff;
        float scatteringCoeff  = cloudsScatteringCoeff;

        vec2 stepScattering = vec2(0.0);
        
        for(int j = 0; j < cloudsMultiScatterSteps; j++) {
            stepScattering.x += scatteringCoeff * exp(-extinctionCoeff * directOpticalDepth) * getCloudsPhase(VdotL, anisotropyFactors) * powderSun;
            stepScattering.x += scatteringCoeff * exp(-extinctionCoeff * groundOpticalDepth) * bouncedLight   * powder;
            stepScattering.y += scatteringCoeff * exp(-extinctionCoeff * skyOpticalDepth)    * isotropicPhase * powderSky;

            extinctionCoeff   *= cloudsExtinctionFalloff;
            scatteringCoeff   *= cloudsScatteringFalloff;
            anisotropyFactors *= cloudsAnisotropyFalloff;
        }
        float scatteringIntegral = (1.0 - stepTransmittance) / cloudsScatteringCoeff;

        scattering    += stepScattering * scatteringIntegral * transmittance;
        transmittance *= stepTransmittance;
    }
    transmittance = clamp01((transmittance - cloudsTransmitThreshold) / (1.0 - cloudsTransmitThreshold));
    distToCloud   = maxEps(depthSum / depthWeight);

    vec3 finalScattering;
    finalScattering += scattering.x * directIlluminance;
    finalScattering += scattering.y * skyIlluminance;

    return vec4(finalScattering, transmittance);
}

float cloudsShadows(vec2 coords, vec3 rayDir, int stepCount) {
    float transmittance = 1.0;

    vec2 cloudsShadowsCoords = coords * viewSize * rcp(cloudsShadowmapRes);
    if(clamp01(cloudsShadowsCoords) != cloudsShadowsCoords) return transmittance;

    vec3 shadowPos     = vec3(cloudsShadowsCoords, 0.0) * 2.0 - 1.0;
         shadowPos.xy *= cloudsShadowmapDist;
         shadowPos     = transMAD(shadowModelViewInverse, shadowPos) + cameraPosition;

    vec2 dists       = intersectSphericalShell(shadowPos + vec3(0.0, earthRad, 0.0), rayDir, innerCloudRad, outerCloudRad);
    float stepLength = (dists.y - dists.x) * rcp(stepCount);

    vec3 increment = rayDir * stepLength;
    vec3 rayPos    = shadowPos + rayDir * (dists.x + stepLength * randF());

    for(int i = 0; i < stepCount; i++, rayPos += increment) {
        transmittance *= getCloudsDensity(rayPos);
    }
    return exp(-transmittance * stepLength);
}

vec3 reprojectClouds(vec3 viewPos) {
    vec3 position     = transMAD(gbufferModelViewInverse, viewPos);
    vec3 cameraOffset = cameraPosition - previousCameraPosition;
    
    position = transMAD(gbufferPreviousModelView, position + gbufferModelViewInverse[3].xyz - cameraOffset);
    return (projOrthoMAD(gbufferPreviousProjection, position) / -position.z) * 0.5 + 0.5;
}
