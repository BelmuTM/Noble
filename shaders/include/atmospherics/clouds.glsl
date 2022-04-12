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

const float windRad = 0.785398;

float getCloudsDensity(vec3 position) {
    if(clamp(position.y, innerCloudRad, outerCloudRad) != position.y) return 0.0;

    float altitude     = (position.y - innerCloudRad) * (1.0 / CLOUDS_THICKNESS);
    vec2 windDirection = WIND_SPEED * sincos(windRad);

    #if ACCUMULATION_VELOCITY_WEIGHT == 0
        position.xz       += windDirection * frameTimeCounter;
    #endif
    position.xz *= 3e-4;

    float globalCoverage = mix(CLOUDS_COVERAGE, 1.0, wetness);

    vec2 weatherNoise = vec2(texture(shadowcolor1, position.xz).g, texture(shadowcolor1, position.xz).r);
    float weatherMap  = max(weatherNoise.r, clamp01(globalCoverage - 0.5) * weatherNoise.g * 2.0);

    float shapeAlter   = heightAlter(altitude,  weatherMap);
    float densityAlter = densityAlter(altitude, weatherMap);

    vec3 curlTex = texture(colortex14, position).rgb * 2.0 - 1.0;
    position    += curlTex * CLOUDS_SWIRL;

    vec4 shapeTex  = texture(depthtex2,  position);
    vec3 detailTex = texture(colortex13, position * 0.002).rgb;

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

    return mix(mix(forwardsLobe, backwardsLobe, cloudsBackScatter), forwardsPeak, cloudsPeakWeight);
}

vec4 cloudsScattering(vec3 rayDir) {

    vec2 dists = intersectSphericalShell(atmosRayPos, rayDir, innerCloudRad, outerCloudRad);
    if(dists.y < 0.0) return vec4(0.0, 0.0, 0.0, 1.0);

    float stepLength = (dists.y - dists.x) / float(CLOUDS_SCATTERING_STEPS);
    vec3 increment   = rayDir * stepLength;
    vec3 rayPos      = atmosRayPos + rayDir * (dists.x + stepLength * randF());

    float VdotL       = dot(rayDir, sceneShadowDir);
    const vec3 up     = vec3(0.0, 1.0, 0.0);
    float bounceLight = maxEps(dot(sceneShadowDir, -up)) * pow2(INV_PI);

    vec3 scattering = vec3(0.0); float transmittance = 1.0;
    
    for(int i = 0; i < CLOUDS_SCATTERING_STEPS; i++, rayPos += increment) {
        if(transmittance <= 5e-2) break;

        float density = getCloudsDensity(rayPos);
        if(density <= 0.0) continue;

        float stepOpticalDepth  = cloudsExtinctionCoeff * density * stepLength;
        float stepTransmittance = exp(-stepOpticalDepth);

        float directOpticalDepth = getCloudsOpticalDepth(rayPos, sceneShadowDir, 12);
        float skyOpticalDepth    = getCloudsOpticalDepth(rayPos, up,              6);
        float groundOpticalDepth = getCloudsOpticalDepth(rayPos,-up,              3);
        vec3 anisotropyFactors   = pow(vec3(cloudsForwLobe, cloudsBackLobe, cloudsForwPeak), vec3(directOpticalDepth + 1.0));

        // Beer's-Powder effect from "The Real-time Volumetric Cloudscapes of Horizon: Zero Dawn" (see sources above)
	    float powder    = 1.0 - exp(-2.0 * density);
	    float powderSun = mix(powder, 1.0, VdotL * 0.5 + 0.5);

        vec2 extinctScatterCoeffs = vec2(cloudsExtinctionCoeff, cloudsScatteringCoeff);
        
        for(int j = 0; j <= 8; j++) {
            scattering += extinctScatterCoeffs.y * exp(-extinctScatterCoeffs.x * vec3(directOpticalDepth, skyOpticalDepth, groundOpticalDepth))
                        * vec3(getCloudsPhase(VdotL, anisotropyFactors) * powderSun, vec2(1.0, bounceLight) * vec2(isotropicPhase * powder));

            extinctScatterCoeffs *= vec2(cloudsExtinctionFalloff, cloudsScatteringFalloff);
            anisotropyFactors    *= cloudsAnisotropyFalloff;
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
