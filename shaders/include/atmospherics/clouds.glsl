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

struct CloudLayer {
    float altitude;
    float thickness;
    float coverage;
    float swirl;
    float scale;
    float frequency;
    float density;

    int steps;
};

vec2 wind = WIND_SPEED * frameTimeCounter * sincos(-0.785398);

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

float getCloudsDensity(vec3 position, CloudLayer layer, vec2 radius) {
    float altitude = (position.y - radius.x) * rcp(layer.thickness);

    #if ACCUMULATION_VELOCITY_WEIGHT == 0
        position.xz += wind;
    #endif

    float weatherMap   = clamp01(FBM(position.xz * layer.scale, 2, layer.frequency) * (1.0 - layer.coverage) + layer.coverage);
    float shapeAlter   = heightAlter(altitude,  weatherMap);
    float densityAlter = densityAlter(altitude, weatherMap);

    position *= 7e-4;

    vec3 curlTex  = texture(colortex14, position * 0.3).rgb * 2.0 - 1.0;
        position += curlTex * layer.swirl;

    float mapCoverage = mix(0.7, 1.0, wetness);

    vec4  shapeTex   = texture(depthtex2, position);
    float shapeNoise = remap(shapeTex.r, -(1.0 - (shapeTex.g * 0.625 + shapeTex.b * 0.25 + shapeTex.a * 0.125)), 1.0, 0.0, 1.0);
          shapeNoise = clamp01(remap(shapeNoise * shapeAlter, 1.0 - mapCoverage * weatherMap, 1.0, 0.0, 1.0));

    vec3  detailTex    = texture(colortex13, position).rgb;
    float detailNoise  = detailTex.r * 0.625 + detailTex.g * 0.25 + detailTex.b * 0.125;
          detailNoise  = mix(detailNoise, 1.0 - detailNoise, clamp01(altitude * 5.0));
          detailNoise *= (0.35 * exp(-mapCoverage * 0.75));

    return clamp01(remap(shapeNoise, detailNoise, 1.0, 0.0, 1.0)) * densityAlter * layer.density;
}

float getCloudsOpticalDepth(vec3 rayPos, vec3 lightDir, int stepCount, CloudLayer layer, vec2 radius) {
    float stepLength = 23.0, opticalDepth = 0.0;

    for(int i = 0; i < stepCount; i++, rayPos += lightDir * stepLength) {
        stepLength *= 2.0;

        opticalDepth += getCloudsDensity(rayPos + lightDir * stepLength * randF(), layer, radius) * stepLength;
    }
    return opticalDepth;
}

float getCloudsPhase(float cosTheta, vec3 anisotropyFactors) {
    float forwardsLobe  = cornetteShanksPhase(cosTheta, anisotropyFactors.x);
    float backwardsLobe = cornetteShanksPhase(cosTheta,-anisotropyFactors.y);
    float forwardsPeak  = cornetteShanksPhase(cosTheta, anisotropyFactors.z);

    return mix(mix(forwardsLobe, backwardsLobe, cloudsBackScatter), forwardsPeak, cloudsPeakWeight);
}

vec4 cloudsScattering(CloudLayer layer, vec3 rayDir) {
    vec2 radius;
         radius.x = planetRadius + layer.altitude;
         radius.y = radius.x + layer.thickness;

    vec2 dists = intersectSphericalShell(atmosRayPos, rayDir, radius.x, radius.y);
    if(dists.y < 0.0) return vec4(0.0, 0.0, 1.0, 1e6);

    float stepLength = (dists.y - dists.x) * rcp(layer.steps);
    vec3 increment   = rayDir * stepLength;
    vec3 rayPos      = atmosRayPos + rayDir * (dists.x + stepLength * randF());

    float VdotL        = dot(rayDir, shadowLightVector);
    const vec3 up      = vec3(0.0, 1.0, 0.0);
    float bouncedLight = abs(dot(rayDir, -up)) * RCP_PI * 0.5 * isotropicPhase;

    vec2 scattering = vec2(0.0);
    float transmittance = 1.0, depthWeight = 0.0, depthSum = 0.0;
    
    for(int i = 0; i < layer.steps; i++, rayPos += increment) {
        if(transmittance <= cloudsTransmitThreshold) break;

        float density = getCloudsDensity(rayPos, layer, radius);
        if(density < EPS) continue;

        depthSum    += distance(atmosRayPos, rayPos) * density; 
        depthWeight += density;

        float stepOpticalDepth  = cloudsExtinctionCoeff * density * stepLength;
        float stepTransmittance = exp(-stepOpticalDepth);

        float directOpticalDepth = getCloudsOpticalDepth(rayPos, shadowLightVector, 8, layer, radius);
        float skyOpticalDepth    = getCloudsOpticalDepth(rayPos, up,                6, layer, radius);
        float groundOpticalDepth = getCloudsOpticalDepth(rayPos,-up,                3, layer, radius);

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
            stepScattering.x += scatteringCoeff * exp(-extinctionCoeff * groundOpticalDepth) * bouncedLight                             * powder;
            stepScattering.y += scatteringCoeff * exp(-extinctionCoeff * skyOpticalDepth)    * isotropicPhase                           * powderSky;

            extinctionCoeff   *= cloudsExtinctionFalloff;
            scatteringCoeff   *= cloudsScatteringFalloff;
            anisotropyFactors *= cloudsAnisotropyFalloff;
        }
        float scatteringIntegral = (1.0 - stepTransmittance) * rcp(cloudsScatteringCoeff);

        scattering    += stepScattering * scatteringIntegral * transmittance;
        transmittance *= stepTransmittance;
    }
    transmittance = linearStep(cloudsTransmitThreshold, 1.0, transmittance);

    return vec4(scattering, transmittance, depthSum / depthWeight);
}

/*
float cloudsShadows(vec2 coords, vec3 rayDir, int stepCount) {
    float transmittance = 1.0;

    vec2 cloudsShadowsCoords = coords * viewSize * rcp(cloudsShadowmapRes);
    if(clamp01(cloudsShadowsCoords) != cloudsShadowsCoords) return transmittance;

    vec3 shadowPos     = vec3(cloudsShadowsCoords, 0.0) * 2.0 - 1.0;
         shadowPos.xy *= cloudsShadowmapDist;
         shadowPos     = transform(shadowModelViewInverse, shadowPos) + cameraPosition;

    vec2 dists       = intersectSphericalShell(shadowPos + vec3(0.0, planetRadius, 0.0), rayDir, innerCloudRad, outerCloudRad);
    float stepLength = (dists.y - dists.x) * rcp(stepCount);

    vec3 increment = rayDir * stepLength;
    vec3 rayPos    = shadowPos + rayDir * (dists.x + stepLength * randF());

    for(int i = 0; i < stepCount; i++, rayPos += increment) {
        transmittance *= getCloudsDensity(rayPos);
    }
    return exp(-transmittance * stepLength);
}
*/

vec3 reprojectClouds(vec3 viewPos, float distanceToClouds) {
    vec3 velocity     = previousCameraPosition - cameraPosition;
         velocity.xz += WIND_SPEED * frameTime * sincos(-0.785398);

    vec3 position = normalize(mat3(gbufferModelViewInverse) * viewPos) * distanceToClouds;
         position = transform(gbufferPreviousModelView, position + gbufferModelViewInverse[3].xyz - velocity);
         position = (projectOrtho(gbufferPreviousProjection, position) / -position.z) * 0.5 + 0.5;
    return position;
}
