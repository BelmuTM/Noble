// Written by Builderb0y

float cubeLength(vec2 coords) {
	return pow(abs(coords.x * coords.x * coords.x) + abs(coords.y * coords.y * coords.y), 1.0 / 3.0);
}

float getDistortFactor(vec2 coords) {
	return cubeLength(coords) + DISTORT_FACTOR;
}

vec3 distort(vec3 coords, float factor) {
	return vec3(coords.xy / factor, coords.z * 0.5);
}

vec3 distort(vec3 coords) {
	return distort(coords, getDistortFactor(coords.xy));
}

vec2 distort2(vec2 coords) {
	float centerDist = length(coords);
	float distortFactor = mix(1.0, centerDist, 0.9);
	return coords / distortFactor;
}
