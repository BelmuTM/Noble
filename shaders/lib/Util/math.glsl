#define PI 3.14159265358979323846
#define EPS 0.001

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

float saturate(float x) {
		return clamp(x, 0.0f, 1.0f);
}

// Written by n_r4h33m#7259
vec3 hemisphereSample(float u, float v, out float cosTheta) {
    float phi = v * 2.0f * PI;
    cosTheta = 1.0f - u;
    float sinTheta = sqrt(1.0f - cosTheta * cosTheta);
    return vec3(cos(phi) * sinTheta, sin(phi) * sinTheta, cosTheta);
}

vec3 hemisphereSample2(float r1, float r2) {
    float sinTheta = sqrt(1.0f - r1 * r1);
    float phi = r2 * 2.0f * PI;
    float x = sinTheta * cos(phi);
    float z = sinTheta * sin(phi);
    return vec3(x, r1, z);
}
