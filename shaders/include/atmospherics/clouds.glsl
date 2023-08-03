/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

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

const CloudLayer cloudLayer0 = CloudLayer(
    CLOUDS_LAYER0_SCATTERING_STEPS,
    CLOUDS_LAYER0_OCTAVES,
    1e-5 + CLOUDS_LAYER0_SCALE       * 9.9e-6,
    1e-5 + CLOUDS_LAYER0_DETAILSCALE * 9.9e-6,
    CLOUDS_LAYER0_FREQUENCY,
    CLOUDS_LAYER0_DENSITY            * 0.01,
    CLOUDS_LAYER0_ALTITUDE,
    CLOUDS_LAYER0_THICKNESS,
    CLOUDS_LAYER0_COVERAGE           * 0.01,
    CLOUDS_LAYER0_SWIRL              * 0.01
);

const CloudLayer cloudLayer1 = CloudLayer(
    CLOUDS_LAYER1_SCATTERING_STEPS,
    CLOUDS_LAYER1_OCTAVES,
    1e-5 + CLOUDS_LAYER1_SCALE       * 9.9e-6,
    1e-5 + CLOUDS_LAYER1_DETAILSCALE * 9.9e-6,
    CLOUDS_LAYER1_FREQUENCY,
    CLOUDS_LAYER1_DENSITY            * 0.01,
    CLOUDS_LAYER1_ALTITUDE,
    CLOUDS_LAYER1_THICKNESS,
    CLOUDS_LAYER1_COVERAGE           * 0.01,
    CLOUDS_LAYER1_SWIRL              * 0.01
);

const vec3 up = vec3(0.0, 1.0, 0.0);
vec3 windDir  = vec3(sincos(-0.785398), 0.0).xzy;
vec3 wind     = CLOUDS_WIND_SPEED * frameTimeCounter * windDir;

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

#define WORLEY__CELL_COUNT (1.0 / 10.0)

vec2 getCellPoint(ivec2 cell) {
    return (vec2(cell) * WORLEY__CELL_COUNT) + (0.5 + 1.5 * rand(vec2(cell))) * WORLEY__CELL_COUNT;
}

float cloudsWorley(vec2 coords) {
    ivec2 cell = ivec2(coords / WORLEY__CELL_COUNT);
    float dist = 1.0;
    
    for (int x = 0; x < 2; x++) { 
        for (int y = 0; y < 2; y++) {
            dist = min(dist, distance(getCellPoint(cell + ivec2(x - 2, y - 2)), coords));
        }
    }
    dist /= length(vec2(WORLEY__CELL_COUNT));
    return pow3(1.0 - dist);
}

float calculateCloudsDensity(vec3 position, CloudLayer layer) {
    float altitude = (position.y - (planetRadius + layer.altitude)) * rcp(layer.thickness);

    #if RENDER_MODE == 0
        position += wind;
    #endif

    bool  isUpperCloudLayer = layer == cloudLayer1;
    float wetnessFactor     = isUpperCloudLayer ? 0.0 : 0.13 * max0(1.0 - wetness);

    layer.coverage += (0.26 * wetness);

    float weatherMap  = FBM(position.xz * layer.scale, layer.octaves, layer.frequency);
          weatherMap  = isUpperCloudLayer ? weatherMap : ((weatherMap - (2.0 * wetnessFactor)) + cloudsWorley(position.xz * 4e-5) * (1.0 + wetnessFactor) - wetnessFactor);
          weatherMap  = weatherMap * (1.0 - layer.coverage) + layer.coverage;

    if(weatherMap < EPS) return 0.0;
    weatherMap = saturate(weatherMap);

    position *= layer.detailScale;

    vec3 curlTex   = texture(noisetex, position * 0.4).rgb * 2.0 - 1.0;
         position += curlTex * layer.swirl;

    vec4  shapeTex   = texture(depthtex2, position);
    float shapeNoise = remap(shapeTex.r, -(1.0 - (shapeTex.g * 0.625 + shapeTex.b * 0.25 + shapeTex.a * 0.125)), 1.0, 0.0, 1.0);
          shapeNoise = saturate(remap(shapeNoise * heightAlter(altitude, weatherMap), 1.0 - mix(0.7, 0.8, wetness * float(!isUpperCloudLayer)) * weatherMap, 1.0, 0.0, 1.0));

    return saturate(shapeNoise) * densityAlter(altitude, weatherMap) * layer.density;
}

float calculateCloudsOpticalDepth(vec3 rayPosition, vec3 lightDirection, int stepCount, CloudLayer layer) {
    float stepSize = 50.0, opticalDepth = 0.0;

    for(int i = 0; i < stepCount; i++, rayPosition += lightDirection * stepSize) {
        opticalDepth += calculateCloudsDensity(rayPosition + lightDirection * stepSize * randF(), layer) * stepSize;
        stepSize     *= 2.0;
    }
    return opticalDepth;
}

float calculateCloudsPhase(float cosTheta, vec3 mieAnisotropyFactors) {
    float forwardsLobe  = henyeyGreensteinPhase(cosTheta,  mieAnisotropyFactors.x);
    float backwardsLobe = henyeyGreensteinPhase(cosTheta, -mieAnisotropyFactors.y);
    float forwardsPeak  = henyeyGreensteinPhase(cosTheta,  mieAnisotropyFactors.z);

    return mix(mix(forwardsLobe, backwardsLobe, cloudsBackScatter), forwardsPeak, cloudsPeakWeight);
}

vec4 estimateCloudsScattering(CloudLayer layer, vec3 rayDirection) {
    float cloudsLowerBound = planetRadius     + layer.altitude;
    float cloudsUpperBound = cloudsLowerBound + layer.thickness;

    vec2 dists = intersectSphericalShell(atmosphereRayPosition, rayDirection, cloudsLowerBound, cloudsUpperBound);
    if(dists.y < 0.0) return vec4(0.0, 0.0, 1.0, 1e6);

    float jitter      = randF();
    float stepSize    = (dists.y - dists.x) / layer.steps;
    vec3  rayPosition = atmosphereRayPosition + rayDirection * (dists.x + stepSize * jitter);
    vec3  increment   = rayDirection * stepSize;

    float distanceToClouds = dists.y;

    float VdotL = dot(rayDirection, shadowLightVector);
    float VdotU = dot(rayDirection, up);
    
    float bouncedLight = abs(-VdotU) * RCP_PI * 0.5 * isotropicPhase;

    vec2  scattering    = vec2(0.0);
    float transmittance = 1.0;
    
    for(int i = 0; i < layer.steps; i++, rayPosition += increment) {
        if(transmittance <= cloudsTransmitThreshold) break;

        float density = calculateCloudsDensity(rayPosition, layer);
        if(density < EPS) continue;

        float stepOpticalDepth  = cloudsExtinctionCoefficient * density * stepSize;
        float stepTransmittance = exp(-stepOpticalDepth);

        float directOpticalDepth = calculateCloudsOpticalDepth(rayPosition, shadowLightVector, 5, layer);
        float groundOpticalDepth = calculateCloudsOpticalDepth(rayPosition,-up,                1, layer);
        float skyOpticalDepth    = calculateCloudsOpticalDepth(rayPosition, up,                2, layer);

	    float powder    = 8.0 * (1.0 - 0.97 * exp(-2.0 * density));
	    float powderSun = mix(powder, 1.0, VdotL * 0.5 + 0.5);
        float powderSky = mix(powder, 1.0, VdotU * 0.5 + 0.5);

        vec3 mieAnisotropyFactors   = pow(vec3(cloudsForwardsLobe, cloudsBackardsLobe, cloudsForwardsPeak), vec3(directOpticalDepth + 1.0));
        float extinctionCoefficient = cloudsExtinctionCoefficient;
        float scatteringCoefficient = cloudsScatteringCoefficient;

        vec2 stepScattering = vec2(0.0);
        
        for(int j = 0; j < cloudsMultiScatterSteps; j++) {
            float cloudsPhase = calculateCloudsPhase(VdotL, mieAnisotropyFactors);

            stepScattering.x += scatteringCoefficient * exp(-extinctionCoefficient * directOpticalDepth) * cloudsPhase    * powderSun;
            stepScattering.x += scatteringCoefficient * exp(-extinctionCoefficient * groundOpticalDepth) * bouncedLight   * powder;
            stepScattering.y += scatteringCoefficient * exp(-extinctionCoefficient * skyOpticalDepth   ) * isotropicPhase * powderSky;

            extinctionCoefficient *= cloudsExtinctionFalloff;
            scatteringCoefficient *= cloudsScatteringFalloff;
            mieAnisotropyFactors  *= cloudsAnisotropyFalloff;
        }
        float scatteringIntegral = (1.0 - stepTransmittance) * rcp(cloudsScatteringCoefficient);

        scattering    += stepScattering * scatteringIntegral * transmittance;
        transmittance *= stepTransmittance;

        distanceToClouds = min((i + jitter) * stepSize + dists.x, distanceToClouds);
    }

    transmittance = linearStep(cloudsTransmitThreshold, 1.0, transmittance);
    vec4 result   = vec4(scattering, transmittance, distanceToClouds);

    result.rgb = mix(vec3(0.0, 0.0, 1.0), result.rgb, max0(exp2(-5e-5 * result.a)));
    return result;
}

float calculateCloudsShadows(vec3 shadowPosition, vec3 rayDirection, CloudLayer layer, int stepCount) {
    float cloudsLowerBound = planetRadius     + layer.altitude;
    float cloudsUpperBound = cloudsLowerBound + layer.thickness;

    vec2 dists = intersectSphericalShell(shadowPosition, rayDirection, cloudsLowerBound, cloudsUpperBound);

    float stepSize   = (dists.y - dists.x) * rcp(stepCount);
    vec3 increment   = rayDirection * stepSize;
    vec3 rayPosition = shadowPosition + rayDirection * (dists.x + stepSize * 0.5);

    float opticalDepth = 0.0;

    for(int i = 0; i < stepCount; i++, rayPosition += increment) {
        opticalDepth += calculateCloudsDensity(rayPosition, layer);
    }
    return exp(-cloudsExtinctionCoefficient * opticalDepth * stepSize);
}

vec3 reprojectClouds(vec3 viewPosition, float distanceToClouds) {
    vec3 scenePosition = normalize((gbufferModelViewInverse * vec4(viewPosition, 1.0)).xyz) * distanceToClouds;
    vec3 velocity      = previousCameraPosition - cameraPosition - CLOUDS_WIND_SPEED * frameTime * windDir;

    vec4 prevPosition = gbufferPreviousModelView * vec4(scenePosition + velocity, 1.0);
         prevPosition = gbufferPreviousProjection * vec4(prevPosition.xyz, 1.0);
    return prevPosition.xyz / prevPosition.w * 0.5 + 0.5;
}
