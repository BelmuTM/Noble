#define PI 3.141592653589793238462
#define PI2 6.28318530718
#define EPS 0.001

struct Ray {
    vec3 pos;
    vec3 dir;
    vec4 color;
};
/*
mat3 calculateTBN(vec3 normal) {
	vec3 tangent  = gl_NormalMatrix * (at_tangent.xyz / at_tangent.w);
    return mat3(tangent, cross(tangent, normal), normal);
}*/

bool isNan(float x) {
    return (x < 0.0f || 0.0f < x || x == 0.0f) ? false : true;
}

float distanceSquared(vec3 v1, vec3 v2) {
	vec3 u = v2 - v1;
	return dot(u, u);
}

float sdSphere(vec3 rayPos, vec3 spherePos, float radius)  {
    return length(rayPos - spherePos) - radius;
}

float cdist(vec2 coord) {
	return max(abs(coord.x - 0.5f), abs(coord.y - 0.5f)) * 1.85f;
}

float distx(float dist) {
    return (far * (dist - near)) / (dist * (far - near));
}

float saturate(float x) {
	return clamp(x, 0.0f, 1.0f);
}

/*
		Thanks to the 2 people who gave me
		their hemisphere sampling functions! <3
*/

// Written by n_r4h33m#7259
vec3 hemisphereSample(float u, float v) {
    float phi = v * 2.0f * PI;
    float cosTheta = 1.0f - u;
    float sinTheta = sqrt(1.0f - cosTheta * cosTheta);
    return vec3(cos(phi) * sinTheta, sin(phi) * sinTheta, cosTheta);
}

// Written by xirreal#0281
vec3 cosWeightedRandomHemisphereDirection(vec3 n, inout vec2 seed) {
    vec2 r = hash22(seed);
    vec3  uu = normalize(cross(n, vec3(0.0f, 1.0f, 1.0f)));
    vec3  vv = cross(uu, n);

    float ra = sqrt(r.y);
    float rx = ra * cos(6.2831f * r.x);
    float ry = ra * sin(6.2831f * r.x);
    float rz = sqrt(1.0f - r.y);
    vec3  rr = vec3(rx * uu + ry * vv + rz * n);

    return normalize(rr);
}
