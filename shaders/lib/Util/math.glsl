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
