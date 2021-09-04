/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec2 encodeNormal(vec3 normal) {
    return normal.xy / sqrt(normal.z * 8.0 + 8.0) + 0.5;
}

vec3 decodeNormal(vec2 encodedNormal) {
    vec2 fenc = encodedNormal * 4.0 - 2.0;
    float f = dot(fenc, fenc);
    float g = sqrt(1.0 - f / 4.0);
    return vec3(fenc * g, 1.0 - f / 2.0);
}

float pack2x8(vec2 x) {
	return dot(floor(255.0 * x + 0.5), vec2(1.0 / 65535.0, 256.0 / 65535.0));
}

float pack2x8Dithered(vec2 x, float pattern) {
	return dot(floor(255.0 * x + pattern), vec2(1.0 / 65535.0, 256.0 / 65535.0));
}

vec2 unpack2x8(float pack) {
	pack *= 65535.0 / 256.0;
	vec2 xy; xy.y = floor(pack); xy.x = pack - xy.y;
	return vec2(256.0 / 255.0, 1.0 / 255.0) * xy;
}

float distanceSquared(vec3 v1, vec3 v2) {
	vec3 u = v2 - v1;
	return dot(u, u);
}

float sdSphere(vec3 rayPos, vec3 spherePos, float radius)  {
    return length(rayPos - spherePos) - radius;
}

float saturate(float x) {
	return clamp(x, 0.0, 1.0);
}

// https://seblagarde.wordpress.com/2014/12/01/inverse-trigonometric-functions-gpu-optimization-for-amd-gcn-architecture/
float ACos(in float x) { 
    x = abs(x); 
    float res = -0.156583 * x + HALF_PI; 
    res *= sqrt(1.0 - x); 
    return (x >= 0) ? res : PI - res; 
}

float ASin(float x) {
    return HALF_PI - ACos(x);
}

float ATanPos(float x)  { 
    float t0 = (x < 1.0) ? x : 1.0 / x;
    float t1 = t0 * t0;
    float poly = 0.0872929;
    poly = -0.301895 + poly * t1;
    poly = 1.0 + poly * t1;
    poly = poly * t0;
    return (x < 1.0) ? poly : HALF_PI - poly;
}

float ATan(float x) {     
    float t0 = ATanPos(abs(x));     
    return (x < 0.0) ? -t0 : t0; 
}

// Provided by LVutner.#1925
vec3 hemisphereSample(vec2 r) {
    float phi = r.x * 2.0 * PI;
    float cosTheta = 1.0 - r.y;
    float sinTheta = sqrt(1.0 - cosTheta * cosTheta);
    return vec3(cos(phi) * sinTheta, sin(phi) * sinTheta, cosTheta);
}

// Provided by xirreal#0281
vec3 randomHemisphereDirection(vec2 r) {
    float radius = sqrt(r.y);
    float xOffset = radius * cos(PI2 * r.x);
    float yOffset = radius * sin(PI2 * r.x);
    float zOffset = sqrt(1.0 - r.y);
    return normalize(vec3(xOffset, yOffset, zOffset));
}
