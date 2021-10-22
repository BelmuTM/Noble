/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/*
    SOURCES / CREDITS:

    ScratchaPixel:   https://www.scratchapixel.com/lessons/procedural-generation-virtual-worlds/simulating-sky/simulating-colors-of-the-sky
    Wikipedia:       https://fr.wikipedia.org/wiki/Th%C3%A9orie_de_Mie
    Sebastian Lague: https://www.youtube.com/watch?v=DxfEbulyFcY
    LVutner:         https://www.shadertoy.com/view/stSGRy
    gltracy:   https://www.shadertoy.com/view/lslXDr
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

#define SCATTER_STEPS      16
#define TRANSMITTANCE_STEPS 8

vec3 atmosphericScattering(vec3 rayOrigin, vec3 rayDir) {
    vec3 lightDir = normalize(viewToWorld(sunPosition));
    vec2 dist = raySphere(rayOrigin, rayDir, atmosRad);

    float tMin = 0.0, tMax = 1e8;
    float t0 = dist.x, t1 = dist.y;
    if(t0 > tMin && t0 > 0.0) { tMin = t0; }
    if(t1 < tMax) { tMax = t1; }

    float iStepSize = (tMax - tMin) / float(SCATTER_STEPS);
    vec3 rayPos = rayOrigin + (rayDir * iStepSize) * 0.5;
    
    vec3 totalRlh = vec3(0.0), totalMie = vec3(0.0);
    float iOdRlh = 0.0, iOdMie = 0.0;

    float VdotL = max(0.0, dot(rayDir, lightDir));
    float pMie  = miePhase(VdotL);
    float pRlh  = rayleighPhase(VdotL);

    for(int i = 0; i < SCATTER_STEPS; i++) {

        float iHeight = length(rayPos) - earthRad;
        float oDStepRlh = exp(-iHeight / hR) * iStepSize;
        float oDStepMie = exp(-iHeight / hM) * iStepSize;

        iOdRlh += oDStepRlh;
        iOdMie += oDStepMie;

        float jStepSize = raySphere(rayPos, lightDir, atmosRad).y / float(TRANSMITTANCE_STEPS);
        vec3 jRayPos = rayPos + (lightDir * jStepSize) * 0.5;

        float jOdRlh = 0.0, jOdMie = 0.0;

        for(int j = 0; j < TRANSMITTANCE_STEPS; j++) {
            float jHeight = length(jRayPos) - earthRad;

            jOdRlh += exp(-jHeight / hR) * jStepSize;
            jOdMie += exp(-jHeight / hM) * jStepSize;

            jRayPos += sunDir * jStepSize;
        }

        vec3 extinction = exp(-(kMie[1] * (iOdMie + jOdMie) + kRlh * (iOdRlh + jOdRlh)));
        totalRlh += oDStepRlh * extinction;
        totalMie += oDStepMie * extinction;

        rayPos += rayDir * iStepSize;
    }

    return 22.0 * (pRlh * kRlh * totalRlh + pMie * kMie[0] * totalMie);
}
