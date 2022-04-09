/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* 
    SOURCES / CREDITS:
    EA:                       https://media.contentapi.ea.com/content/dam/eacom/frostbite/files/s2016-pbs-frostbite-sky-clouds-new.pdf
    Rurik Högfeldt:           https://odr.chalmers.se/bitstream/20.500.12380/241770/1/241770.pdf
    Fredrik Häggström:        http://www.diva-portal.org/smash/get/diva2:1223894/FULLTEXT01.pdf
    LVutner:                  https://www.shadertoy.com/view/stScDz - LVutner#5199
    Sony Pictures Imageworks: http://magnuswrenninge.com/wp-content/uploads/2010/03/Wrenninge-OzTheGreatAndVolumetric.pdf
*/

float heightAlter(float altitude, float weatherMap) {
    float stopHeight = clamp01(weatherMap + 0.12);

    float heightAlter  = clamp01(remap(altitude, 0.0, 0.07, 0.0, 1.0));
          heightAlter *= clamp01(remap(altitude, stopHeight * 0.2, stopHeight, 1.0, 0.0));
    return heightAlter;
}

float densityAlter(float altitude, float weatherMap) {
    float densityAlter  = altitude * clamp01(remap(altitude, 0.0, 0.2, 0.0, 1.0));
          densityAlter *= weatherMap * 2.0;
          densityAlter *= clamp01(remap(altitude, 0.9, 1.0, 1.0, 0.0));
    return densityAlter;
}

const float windRad = 0.785398;

float getCloudsDensity(vec3 position) {
    if(clamp(position.y, innerCloudRad, outerCloudRad) != position.y) return 0.0;

    float altitude     = (length(position) - innerCloudRad) * (1.0 / CLOUDS_THICKNESS);
    vec2 windDirection = WIND_SPEED * sincos(windRad);
    position.xz       += windDirection * frameTimeCounter;

    float weatherMap   = mix(0.3, 0.7, voronoise(position.xz * 2e-4, 1, 1));
    float shapeAlter   = heightAlter(altitude,  weatherMap);
    float densityAlter = densityAlter(altitude, weatherMap);
    
    float coverage       = mix(0.3, 0.7, 1.0 - voronoise(position.xz * 6e-5, 1, 1));
    float globalCoverage = mix(CLOUDS_COVERAGE + coverage, 1.0, wetness);

    float densityNoise  = voronoise(position.xz * 2e-4, 1, 1);
          densityNoise  = mix(densityNoise, 1.0 - densityNoise, clamp01(altitude * 5.0));
          densityNoise *= 0.35 * exp(-globalCoverage * 0.75);

    float shapeNoise = FBM(position * 2e-3, 3);
          shapeNoise = clamp01(remap(shapeNoise * shapeAlter, 1.0 - globalCoverage * weatherMap, 1.0, 0.0, 1.0));

    return clamp01(remap(shapeNoise, densityNoise, 1.0, 0.0, 1.0)) * densityAlter;
}

float getCloudsOpticalDepth(vec3 rayPos, vec3 lightDir, int stepCount) {
    float stepLength = 25.0, opticalDepth = 0.0;

    for(int i = 0; i < stepCount; i++, rayPos += lightDir * stepLength) {
        opticalDepth += getCloudsDensity(rayPos) * stepLength;
        stepLength   *= 1.5;
    }
    return opticalDepth;
}

float getCloudsPhase(float cosTheta, vec3 anisotropyFactors) {
    float forwardsLobe  = cornetteShanksPhase(cosTheta, anisotropyFactors.x);
    float backwardsLobe = cornetteShanksPhase(cosTheta,-anisotropyFactors.y);
    float forwardsPeak  = cornetteShanksPhase(cosTheta, anisotropyFactors.z);

    return mix(mix(forwardsLobe, backwardsLobe, cloudsBackScatter), forwardsPeak, cloudsPeak);
}

vec4 cloudsScattering(vec3 rayDir) {

    vec2 dists = intersectSphericalShell(atmosRayPos, rayDir, innerCloudRad, outerCloudRad);
    if(dists.y < 0.0) return vec4(0.0, 0.0, 0.0, 1.0);

    float stepLength = (dists.y - dists.x) / float(CLOUDS_STEPS);
    vec3 increment   = rayDir * stepLength;
    vec3 rayPos      = atmosRayPos + rayDir * (dists.x + stepLength * randF());

    float VdotL   = dot(rayDir, sceneShadowDir);
    const vec3 up = vec3(0.0, 1.0, 0.0);

    vec3 scattering = vec3(0.0); float transmittance = 1.0;
    
    for(int i = 0; i < CLOUDS_STEPS; i++, rayPos += increment) {
        if(transmittance <= 5e-2) break;

        float density = getCloudsDensity(rayPos);
        if(density <= 0.0) continue;

        float stepOpticalDepth     = cloudsExtinctionCoeff * density * stepLength;
        float stepTransmittance    = exp(-stepOpticalDepth);

        float directOpticalDepth = getCloudsOpticalDepth(rayPos, sceneShadowDir, 12);
        float skyOpticalDepth    = getCloudsOpticalDepth(rayPos, up,              6);
        vec3 anisotropyFactors   = pow(vec3(0.40, 0.35, 0.90), vec3(directOpticalDepth + 1.0));

        float powder  = 1.0 - exp2(-stepOpticalDepth * 2.0);

        float extinctionCoeff = cloudsExtinctionCoeff;
        float scatteringCoeff = cloudsScatteringCoeff;
        
        for(int j = 0; j <= 8; j++) {
            scattering.x += scatteringCoeff * exp(-extinctionCoeff * directOpticalDepth) * getCloudsPhase(VdotL, anisotropyFactors) * powder;
            scattering.y += scatteringCoeff * exp(-extinctionCoeff * skyOpticalDepth)    * isotropicPhase * powder;

            extinctionCoeff   *= cloudsExtinctionFalloff;
            scatteringCoeff   *= cloudsScatteringFalloff;
            anisotropyFactors *= cloudsAnisotropyFalloff;
        }
        vec3 scatteringIntegral = (scattering - scattering * stepTransmittance) / maxEps(stepOpticalDepth);

        scattering    += scatteringIntegral * transmittance;
        transmittance *= stepTransmittance;
    }

    vec3 directIlluminance = sampleDirectIlluminance();

    scattering += scattering.x * directIlluminance;
    scattering += scattering.y * texture(colortex6, texCoords).rgb;

    return vec4(scattering, transmittance);
}
