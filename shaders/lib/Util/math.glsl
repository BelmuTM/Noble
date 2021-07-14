/***********************************************/
/*       Copyright (C) Noble SSRT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

float distanceSquared(vec3 v1, vec3 v2) {
	vec3 u = v2 - v1;
	return dot(u, u);
}

float sdSphere(vec3 rayPos, vec3 spherePos, float radius)  {
    return length(rayPos - spherePos) - radius;
}

float cdist(vec2 coord) {
	return max(abs(coord.x - 0.5), abs(coord.y - 0.5)) * 1.85;
}

float distx(float dist) {
    return (far * (dist - near)) / (dist * (far - near));
}

float saturate(float x) {
	return clamp(x, 0.0, 1.0);
}

/*
	Thanks to the 2 people who gave me
	their hemisphere sampling functions! <3
*/

// Provided by LVutner.#1925
vec3 hemisphereSample(float u, float v) {
    float phi = v * 2.0 * PI;
    float cosTheta = 1.0 - u;
    float sinTheta = sqrt(1.0 - cosTheta * cosTheta);
    return vec3(cos(phi) * sinTheta, sin(phi) * sinTheta, cosTheta);
}

// Provided by LVutner.#1925
vec3 importanceSampleCos(vec3 N, vec2 Xi) {
    float Phi = 2.0 * PI * Xi.y;
    float cosTheta = sqrt(max(0.0, 1.0 - Xi.x));
    float sinTheta = sqrt(Xi.x);

    // Cartesian coords
    vec3 L;
    L.x = sinTheta * cos(Phi);
    L.y = sinTheta * sin(Phi);
    L.z = cosTheta;

    // TBN
    vec3 B = abs(N.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
    vec3 T = normalize(cross(B, N));
    B = cross(N, T);
    
    // World / view coords
    L = vec3(T * L.x + B * L.y + N * L.z);
    L = normalize(L);
    
    return L;
}

// Provided by xirreal#0281
vec3 randomHemisphereDirection(vec3 normal, vec2 r) {
    vec3 tangent = normalize(cross(normal, vec3(0.0, 1.0, 1.0)));
    vec3 bitangent = cross(tangent, normal);

    float radius = sqrt(r.y);
    float xOffset = radius * cos(PI2 * r.x);
    float yOffset = radius * sin(PI2 * r.x);
    float zOffset = sqrt(1.0 - r.y);
    vec3 direction = xOffset * tangent + yOffset * bitangent + zOffset * normal;

    return normalize(direction);
}
