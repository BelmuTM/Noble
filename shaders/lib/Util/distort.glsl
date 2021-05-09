// Written by Builderb0y

#define DISTORT_FACTOR 0.05 //Lower numbers mean better shadows near you and worse shadows farther away. [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.10 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.20 0.21 0.22 0.23 0.24 0.25]
#define SHADOW_BIAS 0.03 //Increase this if you get shadow acne. Decrease this if you get peter panning. [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.10]

float cubeLength(vec2 v) {
	  return pow(abs(v.x * v.x * v.x) + abs(v.y * v.y * v.y), 1.0f / 3.0f);
}

float getDistortFactor(vec2 v) {
	  return cubeLength(v) + DISTORT_FACTOR;
}

vec3 distort(vec3 v, float factor) {
	  return vec3(v.xy / factor, v.z * 0.5);
}

vec3 distort(vec3 v) {
	  return distort(v, getDistortFactor(v.xy));
}
