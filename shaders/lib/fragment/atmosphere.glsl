/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

const float g        = 0.76;
const float gg       = g * g;

const float earthRad = 6371e3;
const float atmosRad = 110e3;

/*
    SOURCES / CREDITS:

    Wikipedia:       https://fr.wikipedia.org/wiki/Th%C3%A9orie_de_Mie
    Sebastian Lague: https://www.youtube.com/watch?v=DxfEbulyFcY
    LVutner:         https://www.shadertoy.com/view/stSGRy
    valentingalea:   https://www.shadertoy.com/view/XtBXDz
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

float raySphere(vec3 ro, vec3 rd, float radius) {
	float b = dot(ro, rd);
	float c = dot(ro, ro) - rad * rad;
	float h = b * b - c;
	if(h < 0.0) return vec2(-1.0);
    return -b - sqrt(h);
}

#define IN_SCATTER_STEPS 16

vec3 inScattered(vec3 rayOrigin, vec3 rayDir, float rayLength) {
    vec3 rayPos = rayOrigin;
    float stepSize = 1.0 / IN_SCATTER_STEPS;
    vec3 scattered = vec3(0.0);

    float VdotL = max(0.0, dot(normalize(rayOrigin), sunDir));
    float pMie  = miePhase(VdotL);
    float pRylh = rayleighPhase(VdotL);

    for(int i = 0; i < IN_SCATTER_STEPS; i++) {
        float sunRayLength = raySphere(rayOrigin, rayDir, atmosRad);

        rayPos += stepSize;
    }
}
