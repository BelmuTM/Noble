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

    SixthSurge (noise generator for clouds shape): https://github.com/sixthsurge - SixthSurge#3922
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

    float altitude     = (position.y - innerCloudRad) * (1.0 / CLOUDS_THICKNESS);
    vec2 windDirection = WIND_SPEED * sincos(windRad);
    position.xz       += windDirection * frameTimeCounter;

    float coverage       = clamp01(1.0 - voronoise(position.xz * 4e-4, 1, 1));
    float globalCoverage = mix(CLOUDS_COVERAGE + coverage, 0.03, wetness);

    float weatherMap = texture(shadowcolor1, position.xz * 2.5e-4).r;
          weatherMap = clamp01(weatherMap * 2.3 - 0.7);

    float shapeAlter   = heightAlter(altitude,  weatherMap);
    float densityAlter = densityAlter(altitude, weatherMap);

    vec4 shapeTex  = texture(depthtex2,  position.xz * 4e-4);
    vec3 detailTex = texture(colortex13, position.xz * 3e-3).rgb;
    vec3 curlTex   = texture(colortex14, position.xz * 4e-4).rgb;

    detailTex.gb = mix(detailTex.gb, vec2(1.0), blueNoise.rg);
    position    += curlTex * CLOUDS_CURL;

    float shapeNoise = remap(shapeTex.r, (shapeTex.g * 0.625 + shapeTex.b * 0.25 + shapeTex.a * 0.125) - 1.0, 1.0, 0.0, 1.0);
          shapeNoise = clamp01(remap(shapeNoise * shapeAlter, 1.0 - globalCoverage * weatherMap, 1.0, 0.0, 1.0));

    float detailNoise  = detailTex.r * 0.625 + detailTex.g * 0.25 + detailTex.b * 0.125;
          detailNoise  = mix(detailNoise, 1.0 - detailNoise, clamp01(altitude * 5.0));
          detailNoise *= 0.35 * exp(-globalCoverage * 0.75);

    return clamp01(remap(shapeNoise, detailNoise, 1.0, 0.0, 1.0)) * densityAlter;
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

    float VdotL       = dot(rayDir, sceneShadowDir);
    const vec3 up     = vec3(0.0, 1.0, 0.0);
    float bounceLight = abs(dot(sceneShadowDir, -up)) * pow2(INV_PI);

    vec3 scattering = vec3(0.0); float transmittance = 1.0;
    
    for(int i = 0; i < CLOUDS_STEPS; i++, rayPos += increment) {
        if(transmittance <= 5e-2) break;

        float density = getCloudsDensity(rayPos);
        if(density <= 0.0) continue;

        float stepOpticalDepth     = cloudsExtinctionCoeff * density * stepLength;
        float stepTransmittance    = exp(-stepOpticalDepth);

        float directOpticalDepth = getCloudsOpticalDepth(rayPos, sceneShadowDir, 12);
        float skyOpticalDepth    = getCloudsOpticalDepth(rayPos, up,              6);
        float groundOpticalDepth = getCloudsOpticalDepth(rayPos,-up,              3);
        vec3 anisotropyFactors   = pow(vec3(0.40, 0.35, 0.90), vec3(directOpticalDepth + 1.0));

        float powder = 1.0 - exp2(-stepOpticalDepth * 2.0);

        float extinctionCoeff = cloudsExtinctionCoeff;
        float scatteringCoeff = cloudsScatteringCoeff;
        
        for(int j = 0; j <= 8; j++) {
            scattering.x += scatteringCoeff * exp(-extinctionCoeff * directOpticalDepth) * getCloudsPhase(VdotL, anisotropyFactors);
            scattering.y += scatteringCoeff * exp(-extinctionCoeff * skyOpticalDepth)    * isotropicPhase;
            scattering.z += scatteringCoeff * exp(-extinctionCoeff * groundOpticalDepth) * bounceLight * isotropicPhase;
            scattering   *= powder;

            extinctionCoeff   *= cloudsExtinctionFalloff;
            scatteringCoeff   *= cloudsScatteringFalloff;
            anisotropyFactors *= cloudsAnisotropyFalloff;
        }
        vec3 scatteringIntegral = (scattering - scattering * stepTransmittance) / maxEps(stepOpticalDepth);

        scattering    += scatteringIntegral * transmittance;
        transmittance *= stepTransmittance;
    }

    scattering += scattering.x * sampleDirectIlluminance();
    scattering += scattering.y * texture(colortex6, texCoords).rgb;
    scattering += scattering.z;

    return vec4(scattering, transmittance);
}
