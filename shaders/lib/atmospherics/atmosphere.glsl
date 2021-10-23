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
    float num = (1.0 - gg) * (1.0 + (cosTheta*cosTheta));
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

vec3 densities(float height, float atmosphereRadius) {
    float rayLeigh = exp(-height / hR);
    float mie      = exp(-height / hM);
    float ozone    = exp(-max(0.0, (35e3 - height) - atmosphereRadius) / 5e3) * exp(-max(0.0, (height - 35e3) - atmosphereRadius) / 15e3);
    return vec3(rayLeigh, mie, ozone);
}

vec3 atmosphericScattering(vec3 rayOrigin, vec3 rayDir) {
    vec3 lightDir = normalize((mat3(gbufferModelViewInverse) * sunPosition));
    vec2 atmosDist  = raySphere(rayOrigin, rayDir, atmosRad);
    vec2 planetDist = raySphere(rayOrigin, rayDir, earthRad);

    // Step size method from Jessie#7257
    bool planetIntersect = planetDist.y >= 0.0;
    vec2 sd = vec2((planetIntersect && planetDist.x < 0.0) ? planetDist.y : max(atmosDist.x, 0.0), (planetIntersect && planetDist.x > 0.0) ? planetDist.x : atmosDist.y);
    float iStepSize = length(sd.y - sd.x) / float(SCATTER_STEPS);

    vec3 iIncrement = rayDir * iStepSize;
    vec3 rayPos = rayOrigin + iIncrement * 0.5;
    
    vec3 totalScattering = vec3(0.0), iOptDepth = vec3(0.0);

    float VdotL = max(0.0, dot(rayDir, lightDir));
    vec2 phase = vec2(rayleighPhase(VdotL), miePhase(VdotL));

    for(int i = 0; i < SCATTER_STEPS; i++) {
        float iHeight = length(rayPos) - earthRad;
        vec3 iDensity = densities(iHeight, atmosRad);
        iOptDepth += iDensity * iStepSize;

        float jStepSize = raySphere(rayPos, lightDir, atmosRad).y / float(TRANSMITTANCE_STEPS);
        vec3 jIncrement = lightDir * jStepSize;
        vec3 jRayPos = rayPos + jIncrement * 0.5;

        vec3 jTransmittance = vec3(1.0);
        for(int j = 0; j < TRANSMITTANCE_STEPS; j++) {
            float jHeight = length(jRayPos) - earthRad;
            vec3 jDensity = densities(jHeight, atmosRad);
            jTransmittance *= exp(-kExtinction * jDensity * jStepSize);

            jRayPos += jIncrement;
        }
        vec3 iTransmittance = exp(-(kExtinction * iOptDepth));
        vec3 scattering = kScattering * (iStepSize * iDensity.xy * phase);
        totalScattering += (scattering * jTransmittance) * iTransmittance;

        rayPos += iIncrement;
    }
    return SUN_INTENSITY * totalScattering;
}
