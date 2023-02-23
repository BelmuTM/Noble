/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
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
    float shapeScale;
    float frequency;
    float density;

    int steps;
    int octaves;
};

CloudLayer layer0 = CloudLayer(
    CLOUDS_LAYER0_ALTITUDE,
    CLOUDS_LAYER0_THICKNESS,
    CLOUDS_LAYER0_COVERAGE * 0.01,
    CLOUDS_LAYER0_SWIRL    * 0.01,
    CLOUDS_LAYER0_SCALE,
    CLOUDS_LAYER0_SHAPESCALE,
    CLOUDS_LAYER0_FREQUENCY,
    CLOUDS_LAYER0_DENSITY,
    CLOUDS_SCATTERING_STEPS,
    CLOUDS_LAYER0_OCTAVES
);

CloudLayer layer1 = CloudLayer(
    CLOUDS_LAYER1_ALTITUDE,
    CLOUDS_LAYER1_THICKNESS,
    CLOUDS_LAYER1_COVERAGE,
    CLOUDS_LAYER1_SWIRL,
    CLOUDS_LAYER1_SCALE,
    CLOUDS_LAYER1_SHAPESCALE,
    CLOUDS_LAYER1_FREQUENCY,
    CLOUDS_LAYER1_DENSITY,
    10,
    CLOUDS_LAYER1_OCTAVES
);

const vec3 up = vec3(0.0, 1.0, 0.0);
vec3 windDir  = vec3(sin(-0.785398), 0.0, cos(-0.785398));
vec3 wind     = CLOUDS_WIND_SPEED * frameTimeCounter * windDir;

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

#define WORLEY__CELL_COUNT (1.0 / 15.0)

vec2 getCellPoint(ivec2 cell) {
    return (vec2(cell) * WORLEY__CELL_COUNT) + (0.5 + 1.5 * rand(vec2(cell))) * WORLEY__CELL_COUNT;
}

float cloudsWorley(vec2 coords) {
    ivec2 cell = ivec2(coords / WORLEY__CELL_COUNT);
    float dist = 1.0;
    
    for (int x = 0; x < 5; x++) { 
        for (int y = 0; y < 5; y++) {
        	vec2 cellPoint = getCellPoint(cell + ivec2(x - 2, y - 2));
                 dist      = min(dist, distance(cellPoint, coords));
        }
    }
    dist /= length(vec2(WORLEY__CELL_COUNT));
    return pow3(1.0 - dist);
}

float getCloudsDensity(vec3 position, CloudLayer layer) {
    float altitude = (position.y - (planetRadius + layer.altitude)) * rcp(layer.thickness);

    #if RENDER_MODE == 0
        position += wind;
    #endif

    float wetnessFactor = max0(wetness - 0.6);

    float weatherMap = FBM(position.xz * layer.scale, layer.octaves, layer.frequency);
          weatherMap = layer == layer1 ? weatherMap : ((weatherMap - 0.4) + cloudsWorley(position.xz * 4e-5) * 1.2 - 0.2);
          weatherMap = weatherMap * (1.0 - layer.coverage) + layer.coverage;
          weatherMap = weatherMap * (1.0 - wetnessFactor)  + wetnessFactor;
          weatherMap = clamp01(weatherMap);

    if(weatherMap < EPS) return 0.0;

    position *= layer.shapeScale;

    vec3 curlTex  = texture(noisetex, position * 0.4).rgb * 2.0 - 1.0;
        position += curlTex * layer.swirl;

    vec4  shapeTex   = texture(depthtex2, position);
    float shapeNoise = remap(shapeTex.r, -(1.0 - (shapeTex.g * 0.625 + shapeTex.b * 0.25 + shapeTex.a * 0.125)), 1.0, 0.0, 1.0);
          shapeNoise = clamp01(remap(shapeNoise * heightAlter(altitude,  weatherMap), 1.0 - mix(0.7, 0.85, wetness) * weatherMap, 1.0, 0.0, 1.0));

    return clamp01(shapeNoise) * densityAlter(altitude, weatherMap) * layer.density;
}

float getCloudsOpticalDepth(vec3 rayPos, vec3 lightDir, int stepCount, CloudLayer layer) {
    float stepSize = 23.0, opticalDepth = 0.0;

    for(int i = 0; i < stepCount; i++, rayPos += lightDir * stepSize) {
        opticalDepth += getCloudsDensity(rayPos + lightDir * stepSize * randF(), layer) * stepSize;
        stepSize     *= 2.0;
    }
    return opticalDepth;
}

float getCloudsPhase(float cosTheta, vec3 mieAnisotropyFactors) {
    float forwardsLobe  = henyeyGreensteinPhase(cosTheta, mieAnisotropyFactors.x);
    float backwardsLobe = henyeyGreensteinPhase(cosTheta,-mieAnisotropyFactors.y);
    float forwardsPeak  = henyeyGreensteinPhase(cosTheta, mieAnisotropyFactors.z);

    return mix(mix(forwardsLobe, backwardsLobe, cloudsBackScatter), forwardsPeak, cloudsPeakWeight);
}

vec4 cloudsScattering(CloudLayer layer, vec3 rayDir) {
    vec2 radius;
         radius.x = planetRadius + layer.altitude;
         radius.y = radius.x + layer.thickness;

    vec2 dists = intersectSphericalShell(atmosphereRayPos, rayDir, radius.x, radius.y);
    if(dists.y < 0.0) return vec4(0.0, 0.0, 1.0, 1e6);

    float stepSize = (dists.y - dists.x) * rcp(layer.steps);
    vec3 rayPos    = atmosphereRayPos + rayDir * (dists.x + stepSize * randF());
    vec3 increment = rayDir * stepSize;

    float VdotL = dot(rayDir, shadowLightVector);
    float VdotU = dot(rayDir, up);
    
    float bouncedLight = abs(-VdotU) * RCP_PI * 0.5 * isotropicPhase;

    vec2 scattering = vec2(0.0);
    float transmittance = 1.0, sum = 0.0, weight = 0.0;
    
    for(int i = 0; i < layer.steps; i++, rayPos += increment) {
        if(transmittance <= cloudsTransmitThreshold) break;

        float density = getCloudsDensity(rayPos, layer);
        if(density < EPS) continue;

        sum    += distance(atmosphereRayPos, rayPos) * density; 
        weight += density;

        float stepOpticalDepth  = cloudsExtinctionCoefficient * density * stepSize;
        float stepTransmittance = exp(-stepOpticalDepth);

        float directOpticalDepth = getCloudsOpticalDepth(rayPos, shadowLightVector, 5, layer);
        float skyOpticalDepth    = getCloudsOpticalDepth(rayPos, up,                2, layer);
        float groundOpticalDepth = getCloudsOpticalDepth(rayPos,-up,                2, layer);

        // Beer's-Powder effect from "The Real-time Volumetric Cloudscapes of Horizon: Zero Dawn" (see sources above)
	    float powder    = 8.0 * (1.0 - 0.97 * exp(-2.0 * density));
	    float powderSun = mix(powder, 1.0, VdotL * 0.5 + 0.5);
        float powderSky = mix(powder, 1.0, VdotU * 0.5 + 0.5);

        vec3 mieAnisotropyFactors   = pow(vec3(cloudsForwardsLobe, cloudsBackardsLobe, cloudsForwardsPeak), vec3(directOpticalDepth + 1.0));
        float extinctionCoefficient = cloudsExtinctionCoefficient;
        float scatteringCoefficient = cloudsScatteringCoefficient;

        vec2 stepScattering = vec2(0.0);
        
        for(int j = 0; j < cloudsMultiScatterSteps; j++) {
            stepScattering.x += scatteringCoefficient * exp(-extinctionCoefficient * directOpticalDepth) * getCloudsPhase(VdotL, mieAnisotropyFactors) * powderSun;
            stepScattering.x += scatteringCoefficient * exp(-extinctionCoefficient * groundOpticalDepth) * bouncedLight                             * powder;
            stepScattering.y += scatteringCoefficient * exp(-extinctionCoefficient * skyOpticalDepth)    * isotropicPhase                           * powderSky;

            extinctionCoefficient *= cloudsExtinctionFalloff;
            scatteringCoefficient *= cloudsScatteringFalloff;
            mieAnisotropyFactors  *= cloudsAnisotropyFalloff;
        }
        float scatteringIntegral = (1.0 - stepTransmittance) * rcp(cloudsScatteringCoefficient);

        scattering    += stepScattering * scatteringIntegral * transmittance;
        transmittance *= stepTransmittance;
    }

    transmittance = linearStep(cloudsTransmitThreshold, 1.0, transmittance);
    vec4 result   = vec4(scattering, transmittance, sum / weight);

    result.rgb = mix(vec3(0.0, 0.0, 1.0), result.rgb, max(1e-8, exp2(-5e-5 * result.a)));
    return result;
}

float getCloudsShadows(vec3 shadowPos, vec3 rayDir, CloudLayer layer, int stepCount) {
    vec2 radius;
         radius.x = planetRadius + layer.altitude;
         radius.y = radius.x + layer.thickness;

    vec2 dists     = intersectSphericalShell(shadowPos, rayDir, radius.x, radius.y);
    float stepSize = (dists.y - dists.x) * rcp(stepCount);

    vec3 rayPos    = shadowPos + rayDir * (dists.x + stepSize * 0.5);
    vec3 increment = rayDir * stepSize;

    float opticalDepth = 0.0;

    for(int i = 0; i < stepCount; i++, rayPos += increment) {
        opticalDepth += getCloudsDensity(rayPos, layer);
    }
    return exp(-cloudsExtinctionCoefficient * opticalDepth * stepSize);
}

vec3 reprojectClouds(vec3 viewPos, float distanceToClouds) {
    vec3 scenePos = normalize((gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz) * distanceToClouds;
    vec3 velocity = previousCameraPosition - cameraPosition - CLOUDS_WIND_SPEED * frameTime * windDir;

    vec4 prevPos = gbufferPreviousModelView * vec4(scenePos + velocity, 1.0);
         prevPos = gbufferPreviousProjection * vec4(prevPos.xyz, 1.0);
    return prevPos.xyz / prevPos.w * 0.5 + 0.5;
}
