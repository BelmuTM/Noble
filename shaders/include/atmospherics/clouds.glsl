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
    float texDetail;

    int steps;
    int octaves;
};

const vec3 up   = vec3(0.0, 1.0, 0.0);
float windSpeed = 10.0;
vec2 windDir    = sincos(-0.785398);
vec2 wind       = windSpeed * frameTimeCounter * windDir;

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

float getCloudsDensity(vec3 position, CloudLayer layer) {
    float altitude = (position.y - (planetRadius + layer.altitude)) * rcp(layer.thickness);

    #if ACCUMULATION_VELOCITY_WEIGHT == 0
        position.xz += wind;
    #endif

    float mapCoverage = mix(layer.coverage, 1.0, wetness);

    float weatherMap   = clamp01(FBM(position.xz * layer.scale, layer.octaves, layer.frequency) * (1.0 - mapCoverage) + mapCoverage);
    float shapeAlter   = heightAlter(altitude,  weatherMap);
    float densityAlter = densityAlter(altitude, weatherMap);

    position *= layer.texDetail;

    vec3 curlTex  = texture(noisetex, position * 0.3).rgb * 2.0 - 1.0;
        position += curlTex * layer.swirl;

    vec4  shapeTex   = texture(depthtex2, position);
    float shapeNoise = remap(shapeTex.r, -(1.0 - (shapeTex.g * 0.625 + shapeTex.b * 0.25 + shapeTex.a * 0.125)), 1.0, 0.0, 1.0);
          shapeNoise = clamp01(remap(shapeNoise * shapeAlter, 1.0 - 0.7 * weatherMap, 1.0, 0.0, 1.0));

    vec3  detailTex   = texture(colortex13, position).rgb;
    float detailNoise = detailTex.r * 0.625 + detailTex.g * 0.25 + detailTex.b * 0.125;
          detailNoise = mix(detailNoise, 1.0 - detailNoise, clamp01(altitude * 5.0)) * 0.16532829;

    return clamp01(remap(shapeNoise, detailNoise, 1.0, 0.0, 1.0)) * densityAlter * layer.density;
}

float getCloudsOpticalDepth(vec3 rayPos, vec3 lightDir, int stepCount, CloudLayer layer) {
    float stepLength = 23.0, opticalDepth = 0.0;

    for(int i = 0; i < stepCount; i++, rayPos += lightDir * stepLength) {
        opticalDepth += getCloudsDensity(rayPos + lightDir * stepLength * randF(), layer) * stepLength;
        stepLength   *= 2.0;
    }
    return opticalDepth;
}

float getCloudsPhase(float cosTheta, vec3 anisotropyFactors) {
    float forwardsLobe  = henyeyGreensteinPhase(cosTheta, anisotropyFactors.x);
    float backwardsLobe = henyeyGreensteinPhase(cosTheta,-anisotropyFactors.y);
    float forwardsPeak  = henyeyGreensteinPhase(cosTheta, anisotropyFactors.z);

    return mix(mix(forwardsLobe, backwardsLobe, cloudsBackScatter), forwardsPeak, cloudsPeakWeight);
}

vec4 cloudsScattering(CloudLayer layer, vec3 rayDir) {
    vec2 radius;
         radius.x = planetRadius + layer.altitude;
         radius.y = radius.x + layer.thickness;

    vec2 dists = intersectSphericalShell(atmosRayPos, rayDir, radius.x, radius.y);
    if(dists.y < 0.0) return vec4(0.0, 0.0, 1.0, 1e6);

    float stepLength = (dists.y - dists.x) * rcp(layer.steps);
    vec3 rayPos      = atmosRayPos + rayDir * (dists.x + stepLength * randF());
    vec3 increment   = rayDir * stepLength;

    float VdotL = dot(rayDir, shadowLightVector);
    float VdotU = dot(rayDir, up);
    
    float bouncedLight = abs(-VdotU) * RCP_PI * 0.5 * isotropicPhase;

    vec2 scattering = vec2(0.0);
    float transmittance = 1.0, sum = 0.0, weight = 0.0;
    
    for(int i = 0; i < layer.steps; i++, rayPos += increment) {
        if(transmittance <= cloudsTransmitThreshold) break;

        float density = getCloudsDensity(rayPos, layer);
        if(density < EPS) continue;

        sum    += distance(atmosRayPos, rayPos) * density; 
        weight += density;

        float stepOpticalDepth  = cloudsExtinctionCoeff * density * stepLength;
        float stepTransmittance = exp(-stepOpticalDepth);

        float directOpticalDepth = getCloudsOpticalDepth(rayPos, shadowLightVector, 6, layer);
        float skyOpticalDepth    = getCloudsOpticalDepth(rayPos, up,                4, layer);
        float groundOpticalDepth = getCloudsOpticalDepth(rayPos,-up,                2, layer);

        // Beer's-Powder effect from "The Real-time Volumetric Cloudscapes of Horizon: Zero Dawn" (see sources above)
	    float powder    = 8.0 * (1.0 - 0.97 * exp(-2.0 * density));
	    float powderSun = mix(powder, 1.0, VdotL * 0.5 + 0.5);
        float powderSky = mix(powder, 1.0, VdotU * 0.5 + 0.5);

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
    vec4 result   = vec4(scattering, transmittance, sum / weight);

    // Aerial Perspective
    result.rgb = mix(vec3(0.0, 0.0, 1.0), result.rgb, exp2(-5e-5 * result.a));

    return result;
}

vec3 getCloudsShadowPos(vec2 coords) {
    vec3 shadowPos     = vec3(coords, 0.0) * 2.0 - 1.0;
         shadowPos.xy *= cloudsShadowmapDist;
    return transform(shadowModelViewInverse, shadowPos) + atmosRayPos;
}

vec2 getCloudsShadowCoords(vec3 position) {
    vec2 shadowCoords  = transform(shadowModelView, position).xy;
         shadowCoords *= rcp(cloudsShadowmapDist);
    return shadowCoords * 0.5 + 0.5;
}

float cloudsShadows(vec3 shadowPos, vec3 rayDir, CloudLayer layer, int stepCount) {
    float transmittance = 1.0;

    vec2 radius;
         radius.x = planetRadius + layer.altitude;
         radius.y = radius.x + layer.thickness;

    vec2 dists       = intersectSphericalShell(shadowPos, rayDir, radius.x, radius.y);
    float stepLength = (dists.y - dists.x) * rcp(stepCount);

    vec3 rayPos    = shadowPos + rayDir * (dists.x + stepLength * randF());
    vec3 increment = rayDir * stepLength;

    for(int i = 0; i < stepCount; i++, rayPos += increment) {
        transmittance *= getCloudsDensity(rayPos, layer);
    }
    return exp(-transmittance * stepLength);
}

vec3 reprojectClouds(vec3 viewPos, float distanceToClouds) {
    vec3 velocity     = previousCameraPosition - cameraPosition;
         velocity.xz += windSpeed * frameTime * windDir;

    vec3 position = normalize(mat3(gbufferModelViewInverse) * viewPos) * distanceToClouds;
         position = transform(gbufferPreviousModelView, position + gbufferModelViewInverse[3].xyz - velocity);
         position = (projectOrtho(gbufferPreviousProjection, position) / -position.z) * 0.5 + 0.5;
    return position;
}
