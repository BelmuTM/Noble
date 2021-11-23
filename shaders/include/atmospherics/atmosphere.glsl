/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/*
    SOURCES / CREDITS:
    Thanks LVutner#5199 and Jessie#7257 for the help!

    ScratchaPixel:   https://www.scratchapixel.com/lessons/procedural-generation-virtual-worlds/simulating-sky/simulating-colors-of-the-sky
    Wikipedia:       https://fr.wikipedia.org/wiki/Th%C3%A9orie_de_Mie
    Sebastian Lague: https://www.youtube.com/watch?v=DxfEbulyFcY
    LVutner:         https://www.shadertoy.com/view/stSGRy
    gltracy:         https://www.shadertoy.com/view/lslXDr
*/

float rayleighPhase(float cosTheta) {
    const float rayleigh = 3.0 / (16.0 * PI);
    return rayleigh * (1.0 + (cosTheta * cosTheta));
}

float miePhase(float cosTheta) {
    const float mie = 3.0 / (8.0 * PI);
    float num = (1.0 - gg) * (1.0 + (cosTheta * cosTheta));
    float denom = (2.0 + gg) * pow(1.0 + gg - 2.0 * g * cosTheta, 1.5);
    return mie * (num / denom);
}

// Provided by LVutner#5199
vec2 raySphere(vec3 ro, vec3 rd, float rad) {
	float b = dot(ro, rd);
	float c = dot(ro, ro) - rad * rad;
	float d = b * b - c;
	if(d < 0.0) return vec2(1.0, -1.0);
	d = sqrt(d);
	return vec2(-b - d, -b + d);
}

vec3 densities(float height) {
    float rayLeigh = exp(-height / hR);
    float mie      = exp(-height / hM);
    float ozone    = exp(-max0((35e3 - height) - atmosRad) / 5e3) * exp(-max0((height - 35e3) - atmosRad) / 15e3);
    return vec3(rayLeigh, mie, ozone);
}

vec3 atmosphereTransmittance(vec3 rayOrigin, vec3 lightDir) {
    float stepSize = raySphere(rayOrigin, lightDir, atmosRad).y / float(TRANSMITTANCE_STEPS);
    vec3 increment = lightDir * stepSize;
    vec3 rayPos = rayOrigin + increment * 0.5;

    vec3 transmittance = vec3(1.0);
    for(int j = 0; j < TRANSMITTANCE_STEPS; j++) {
        vec3 density = densities(length(rayPos) - earthRad);
        transmittance *= exp(-kExtinction * density * stepSize);
        rayPos += increment;
    }
    return transmittance;
}

vec3 atmosphericScattering(vec3 rayOrigin, vec3 rayDir, vec3 skyIlluminance) {
    vec2 atmosDist  = raySphere(rayOrigin, rayDir, atmosRad);
    vec2 planetDist = raySphere(rayOrigin, rayDir, earthRad - 5e3);

    // Step size method from Jessie#7257
    bool planetIntersect = planetDist.y >= 0.0;
    vec2 sd = vec2((planetIntersect && planetDist.x < 0.0) ? planetDist.y : max(atmosDist.x, 0.0), (planetIntersect && planetDist.x > 0.0) ? planetDist.x : atmosDist.y);
    float stepSize = length(sd.y - sd.x) / float(SCATTER_STEPS);

    vec3 increment = rayDir * stepSize;
    vec3 rayPos = rayOrigin + increment * 0.5;

    float sunVdotL  = max0(dot(rayDir, playerSunDir));
    float moonVdotL = max0(dot(rayDir, playerMoonDir));
    vec4 phase = vec4(rayleighPhase(sunVdotL), miePhase(sunVdotL), rayleighPhase(moonVdotL), miePhase(moonVdotL));

    vec3 scattering = vec3(0.0), multipleScattering = vec3(0.0), transmittance = vec3(1.0);
    
    for(int i = 0; i < SCATTER_STEPS; i++) {
        vec3 airmass = densities(length(rayPos) - earthRad) * stepSize;
        vec3 stepOpticalDepth = -kExtinction * airmass;

        vec3 stepTransmittance  = exp(stepOpticalDepth);
        vec3 visibleScattering  = transmittance * (stepTransmittance - 1.0) / stepOpticalDepth;
        vec3 sunStepScattering  = kScattering * (airmass.xy * phase.xy) * visibleScattering;
        vec3 moonStepScattering = kScattering * (airmass.xy * phase.zw) * visibleScattering;

        scattering += sunStepScattering  * atmosphereTransmittance(rayPos, playerSunDir)  * SUN_ILLUMINANCE;
        scattering += moonStepScattering * atmosphereTransmittance(rayPos, playerMoonDir) * MOON_ILLUMINANCE;
        multipleScattering += visibleScattering * (kScattering * airmass.xy);

        transmittance *= stepTransmittance;
        rayPos += increment;
    }
    skyIlluminance = PI * mix(skyIlluminance, vec3(skyIlluminance.b) * sqrt(2.0), INV_PI);
    multipleScattering *= skyIlluminance * (0.25 / PI);
    
    return max0(multipleScattering + scattering);
}

// Originally written by Capt Tatsu#7124
// Modified by Belmu#4066
float drawStars(vec3 viewPos) {
	vec3 playerPos = mat3(gbufferModelViewInverse) * viewPos;
	vec3 planeCoords = playerPos / (playerPos.y + length(playerPos.xz));
	vec2 coord = planeCoords.xz * 0.7 + cameraPosition.xz * 1e-5 + frameTime * 0.00125;
	coord = floor(coord * 1024.0) / 1024.0;

	float VdotU = clamp01(dot(normalize(viewPos), normalize(upPosition)));
	float multiplier = sqrt(sqrt(VdotU)) * (1.0 - rainStrength);

	float star = 1.0;
	if(VdotU > 0.0) {
		star *= rand(coord.xy);
		star *= rand(-coord.xy + 0.1);
	}
	return clamp01(star - (1.0 - STARS_AMOUNT)) * multiplier;
}
