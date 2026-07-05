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
    [Credits]:
        SixthSurge - providing noise generator program for clouds shape and help with lighting (https://github.com/sixthsurge)
        
    [References]:
        Wrenninge et al. (2013). Oz: The Great and Volumetric. http://magnuswrenninge.com/wp-content/uploads/2010/03/Wrenninge-OzTheGreatAndVolumetric.pdf
        Schneider, A., & Vos, N. (2015). The Real-time Volumetric Cloudscapes of Horizon: Zero Dawn. https://www.guerrilla-games.com/media/News/Files/The-Real-time-Volumetric-Cloudscapes-of-Horizon-Zero-Dawn.pdf
        Hillaire, S. (2016). Physically Based Sky, Atmosphere and Cloud Rendering in Frostbite. https://media.contentapi.ea.com/content/dam/eacom/frostbite/files/s2016-pbs-frostbite-sky-clouds-new.pdf
        Högfeldt, R. (2016). Convincing Cloud Rendering An Implementation of Real-Time Dynamic Volumetric Clouds in Frostbite. https://odr.chalmers.se/server/api/core/bitstreams/c8634b02-1b52-40c7-a75c-d8c7a9594c2c/content
        Häggström, F. (2018). Real-time rendering of volumetric clouds. http://www.diva-portal.org/smash/get/diva2:1223894/FULLTEXT01.pdf
*/

uniform sampler3D depthtex2;
uniform sampler3D shadowcolor1;

struct CloudLayer {
    int steps;
    int octaves;

    float scale;
    float detailScale;
    float frequency;

    float density;

    float altitude;
    float thickness;
    float coverage;
    float swirl;
};

#define PARSE_CLOUD_LAYER_SETTINGS( \
    SCATTERING_STEPS, OCTAVES, SCALE, DETAILSCALE, FREQUENCY, DENSITY, ALTITUDE, THICKNESS, COVERAGE, SWIRL \
) \
    CloudLayer(                      \
        SCATTERING_STEPS,            \
        OCTAVES,                     \
        1e-5 + SCALE       * 9.9e-6, \
        1e-5 + DETAILSCALE * 9.9e-6, \
        FREQUENCY,                   \
        DENSITY            * 0.01,   \
        ALTITUDE,                    \
        THICKNESS,                   \
        COVERAGE           * 0.01,   \
        SWIRL              * 0.01    \
    )

const CloudLayer cloudLayer0 = PARSE_CLOUD_LAYER_SETTINGS(
    CLOUDS_LAYER0_SCATTERING_STEPS,
    CLOUDS_LAYER0_OCTAVES,
    CLOUDS_LAYER0_SCALE,
    CLOUDS_LAYER0_DETAILSCALE,
    CLOUDS_LAYER0_FREQUENCY,
    CLOUDS_LAYER0_DENSITY,
    CLOUDS_LAYER0_ALTITUDE,
    CLOUDS_LAYER0_THICKNESS,
    CLOUDS_LAYER0_COVERAGE,
    CLOUDS_LAYER0_SWIRL
);

const CloudLayer cloudLayer1 = PARSE_CLOUD_LAYER_SETTINGS(
    CLOUDS_LAYER1_SCATTERING_STEPS,
    CLOUDS_LAYER1_OCTAVES,
    CLOUDS_LAYER1_SCALE,
    CLOUDS_LAYER1_DETAILSCALE,
    CLOUDS_LAYER1_FREQUENCY,
    CLOUDS_LAYER1_DENSITY,
    CLOUDS_LAYER1_ALTITUDE,
    CLOUDS_LAYER1_THICKNESS,
    CLOUDS_LAYER1_COVERAGE,
    CLOUDS_LAYER1_SWIRL
);

const vec3 up = vec3(0.0, 1.0, 0.0);

vec3 windDirection = vec3(sincos(-0.785398), 0.0).xzy;
vec3 wind          = CLOUDS_WIND_SPEED * frameTimeCounter * windDirection;

float heightAlter(float altitude, float weatherMap) {
    float stopHeight = saturate(weatherMap + 0.12);

    float heightAlter  = saturate(remap(altitude, 0.0, 0.07, 0.0, 1.0));
          heightAlter *= saturate(remap(altitude, stopHeight * 0.2, stopHeight, 1.0, 0.0));
    return heightAlter;
}

float densityAlter(float altitude, float weatherMap) {
    float densityAlter  = altitude * saturate(remap(altitude, 0.0, 0.2, 0.0, 1.0));
          densityAlter *= saturate(remap(altitude, 0.9, 1.0, 1.0, 0.0));
          densityAlter *= weatherMap * 2.0;
    return densityAlter;
}

const float WORLEY_CELLS_COUNT = 1.0 / 16.0;

vec2 getCellPoint(ivec2 cell) {
    return (cell + hash22(cell)) * WORLEY_CELLS_COUNT;
}

float worley(vec2 coords) {
    ivec2 cell = ivec2(floor(coords / WORLEY_CELLS_COUNT));
    float dist = 1.0;

    const int neighbourhoodSize = 2;
    
    for (int x = -neighbourhoodSize; x < neighbourhoodSize; x++) { 
        for (int y = -neighbourhoodSize; y < neighbourhoodSize; y++) {
            dist = min(dist, distance(getCellPoint(cell + ivec2(x, y)), coords));
        }
    }
    
    return 1.0 - dist / length(vec2(WORLEY_CELLS_COUNT));
}

float calculateCloudsDensity(vec3 position, CloudLayer layer, bool isLowerLayer) {
    float altitude = (position.y - (planetRadius + layer.altitude)) * rcp(layer.thickness);

    #if RENDER_MODE == 0
        position += wind;
    #endif

    layer.coverage += (0.26 * wetness);

    vec2 scaledCoords = position.xz * layer.scale;

    float weatherMap = 0.0;

    if (isLowerLayer) {

        float wetnessFactor = 0.13 * max0(1.0 - wetness);

        float worley = worley(scaledCoords * 0.06);

        weatherMap  = FBM(scaledCoords * 4.0, layer.octaves, layer.frequency);
        weatherMap *= weatherMap;
        weatherMap *= sqrt(texture(noisetex, scaledCoords).g);
        weatherMap += worley * worley * worley * (1.0 + wetnessFactor);
        weatherMap -= wetnessFactor;

    } else {

        weatherMap  = FBM(scaledCoords, layer.octaves, layer.frequency);
        weatherMap *= saturate(texture(noisetex, position.xz * 2e-4).b * 0.8 + 0.5);

    }

    weatherMap = weatherMap * (1.0 - layer.coverage) + layer.coverage;
    weatherMap = mix(weatherMap, 0.0, biome_arid);
    weatherMap = saturate(weatherMap);

    if (weatherMap < EPS) return 0.0;

    position *= layer.detailScale;

    vec3 curlTex   = texture(shadowcolor1, position * 0.4).rgb * 2.0 - 1.0;
         position += curlTex * layer.swirl;

    vec4  shapeTex   = texture(depthtex2, position);
    float shapeNoise = remap(shapeTex.r, -(1.0 - (shapeTex.g * 0.625 + shapeTex.b * 0.25 + shapeTex.a * 0.125)), 1.0, 0.0, 1.0);
          shapeNoise = remap(shapeNoise * heightAlter(altitude, weatherMap), 1.0 - mix(0.72, 0.9, wetness) * weatherMap, 1.0, 0.0, 1.0);

    return saturate(shapeNoise) * densityAlter(altitude, weatherMap) * layer.density;
}

float calculateCloudsOpticalDepth(vec3 rayPosition, vec3 lightDirection, int stepCount, CloudLayer layer, bool isLowerLayer, bool animated) {
    float stepSize = 100.0, opticalDepth = 0.0;

    float jitter = animated ? randF() : bayer32(gl_FragCoord.xy);

    for (int i = 0; i < stepCount; i++) {
        float density = calculateCloudsDensity(rayPosition + lightDirection * stepSize * jitter, layer, isLowerLayer);
        opticalDepth += density * stepSize;
        rayPosition  += lightDirection * stepSize;
    }

    return opticalDepth;
}

float calculateCloudsPhase(float cosTheta, vec3 mieAnisotropyFactors) {
    float forwardsLobe  = henyeyGreensteinPhase(cosTheta,  mieAnisotropyFactors.x);
    float backwardsLobe = henyeyGreensteinPhase(cosTheta, -mieAnisotropyFactors.y);
    float forwardsPeak  = henyeyGreensteinPhase(cosTheta,  mieAnisotropyFactors.z);

    return mix(mix(forwardsLobe, backwardsLobe, cloudsBackScatter), forwardsPeak, cloudsPeakWeight);
}

vec4 estimateCloudsScattering(CloudLayer layer, vec3 rayDirection, bool isLowerLayer, bool animated) {
    float cloudsLowerBound = planetRadius     + layer.altitude;
    float cloudsUpperBound = cloudsLowerBound + layer.thickness;

    vec2 dists = intersectSphericalShell(atmosphereRayPosition, rayDirection, cloudsLowerBound, cloudsUpperBound);
    if (dists.y < 0.0) return vec4(0.0, 0.0, 1.0, 1e9);

    float jitter      = animated ? temporalBlueNoise(gl_FragCoord.xy) : bayer64(gl_FragCoord.xy);
    float stepSize    = (dists.y - dists.x) / layer.steps;
    vec3  rayPosition = atmosphereRayPosition + rayDirection * (dists.x + stepSize * jitter);
    vec3  increment   = rayDirection * stepSize;

    float distanceToClouds = dists.y;

    float VdotL = dot(rayDirection, shadowLightVectorWorld);
    float VdotU = dot(rayDirection, up);
    
    float bouncedLight = abs(-VdotU) * RCP_PI * 0.5 * isotropicPhase;

    vec2  scattering    = vec2(0.0);
    float transmittance = 1.0;

    // Adaptive steps
    int steps = layer.steps;
    
    for (int i = 0; i < steps; i++, rayPosition += increment) {
        if (transmittance <= cloudsTransmitThreshold) break;

        float density = calculateCloudsDensity(rayPosition, layer, isLowerLayer);

        if (density > EPS) {

            float stepOpticalDepth  = cloudsExtinctionCoefficient * density * stepSize;
            float stepTransmittance = exp(-stepOpticalDepth);

            float directOpticalDepth = calculateCloudsOpticalDepth(rayPosition,  shadowLightVectorWorld, 8, layer, isLowerLayer, animated);
            float groundOpticalDepth = calculateCloudsOpticalDepth(rayPosition, -up,                     1, layer, isLowerLayer, animated);
            float skyOpticalDepth    = calculateCloudsOpticalDepth(rayPosition,  up,                     2, layer, isLowerLayer, animated);

            float powder    = 6.5 * (1.0 - 0.97 * exp(-8.0 * density));
            float powderSun = mix(powder, 1.0, VdotL * 0.5 + 0.5);
            float powderSky = mix(powder, 1.0, VdotU * 0.5 + 0.5);

            vec3  mieAnisotropyFactors  = vec3(cloudsForwardsLobe, cloudsBackardsLobe, cloudsForwardsPeak);
            float extinctionCoefficient = cloudsExtinctionCoefficient;
            float scatteringCoefficient = cloudsScatteringCoefficient;

            vec2 stepScattering = vec2(0.0);
            
            float cloudsPhase = calculateCloudsPhase(VdotL, mieAnisotropyFactors);

            mieAnisotropyFactors = pow(mieAnisotropyFactors, vec3(1.0 + directOpticalDepth));
            
            for (int j = 0; j < cloudsMultiScatterSteps; j++) {
                stepScattering.x += scatteringCoefficient * exp(-extinctionCoefficient * directOpticalDepth) * cloudsPhase    * powderSun;
                stepScattering.x += scatteringCoefficient * exp(-extinctionCoefficient * groundOpticalDepth) * bouncedLight   * powder;
                stepScattering.y += scatteringCoefficient * exp(-extinctionCoefficient * skyOpticalDepth   ) * isotropicPhase * powderSky;

                extinctionCoefficient *= cloudsExtinctionFalloff;
                scatteringCoefficient *= cloudsScatteringFalloff;
                mieAnisotropyFactors  *= cloudsAnisotropyFalloff;

                cloudsPhase = calculateCloudsPhase(VdotL, mieAnisotropyFactors);
            }
            
            float scatteringIntegral = (1.0 - stepTransmittance) * rcp(cloudsScatteringCoefficient);

            scattering    += stepScattering * scatteringIntegral * transmittance;
            transmittance *= stepTransmittance;

            distanceToClouds = min((i + jitter) * stepSize + dists.x, distanceToClouds);

        }
    }
    
    transmittance = linearStep(cloudsTransmitThreshold, 1.0, transmittance);

    return vec4(scattering, transmittance, distanceToClouds);
}

#if CLOUDS_SHADOWS == 1

    float calculateCloudsShadows(vec3 shadowPosition, CloudLayer layer, bool isLowerLayer) {
        float cloudsLowerBound = planetRadius     + layer.altitude;
        float cloudsUpperBound = cloudsLowerBound + layer.thickness;

        vec2 dists = intersectSphericalShell(shadowPosition, shadowLightVectorWorld, cloudsLowerBound, cloudsUpperBound);

        float stepSize    = (dists.y - dists.x) * rcp(CLOUDS_SHADOWS_STEPS);
        vec3  increment   = shadowLightVectorWorld * stepSize;
        vec3  rayPosition = shadowPosition + shadowLightVectorWorld * (dists.x + stepSize * 0.5);

        float opticalDepth = 0.0;

        for (int i = 0; i < CLOUDS_SHADOWS_STEPS; i++, rayPosition += increment) {
            opticalDepth += calculateCloudsDensity(rayPosition, layer, isLowerLayer);
        }

        return exp(-cloudsExtinctionCoefficient * opticalDepth * stepSize);
    }

#endif
