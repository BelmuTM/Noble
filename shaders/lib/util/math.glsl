/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* MATH FUNCTIONS */

float clamp01(float x) {
	return clamp(x, 0.0, 1.0);
}

vec2 clamp01(vec2 x) {
    return clamp(x, vec2(0.0), vec2(1.0));
}

vec3 clamp01(vec3 x) {
    return clamp(x, vec3(0.0), vec3(1.0));
}

vec4 clamp01(vec4 x) {
    return clamp(x, vec4(0.0), vec4(1.0));
}

float pow2(float x) { return x*x; }
float pow3(float x) { return x*x*x; }
float pow4(float x) { return pow2(pow2(x)); }
float pow5(float x) { return pow4(x)*x; }

vec2 pow2(vec2 x) { return x*x; }
vec2 pow3(vec2 x) { return x*x*x; }
vec2 pow4(vec2 x) { return pow2(pow2(x)); }
vec2 pow5(vec2 x) { return pow4(x)*x; }

vec3 pow2(vec3 x) { return x*x; }
vec3 pow3(vec3 x) { return x*x*x; }
vec3 pow4(vec3 x) { return pow2(pow2(x)); }
vec3 pow5(vec3 x) { return pow4(x)*x; }

vec4 pow2(vec4 x) { return x*x; }
vec4 pow3(vec4 x) { return x*x*x; }
vec4 pow4(vec4 x) { return pow2(pow2(x)); }
vec4 pow5(vec4 x) { return pow4(x)*x; }

// Improved smoothstep function suggested by Ken Perlin
// https://www.scratchapixel.com/lessons/procedural-generation-virtual-worlds/perlin-noise-part-2/improved-perlin-noise
float quintic(float edge0, float edge1, float x) {
    x = clamp01((x - edge0) / (edge1 - edge0));
    return x * x * x * (x * (x * 6.0 - 15.0) + 10.0);
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

vec2 sincos2(float x) {
    return vec2(sin(x), cos(x));
}

/* MISC */

vec2 projectSphere(in vec3 direction) {
    float longitude = atan(-direction.x, -direction.z);
    float latitude = acos(direction.y);

    return vec2(longitude * (1.0 / TAU) + 0.5, latitude * (1.0 / PI));
}

vec3 unprojectSphere(in vec2 coord) {
    float longitude = coord.x * TAU;
    float latitude = coord.y * PI;
    return vec3(vec2(sin(longitude), cos(longitude)) * sin(latitude), cos(latitude)).xzy;
}

// Provided by LVutner.#1925
vec3 hemisphereSample(vec2 r) {
    float phi = r.x * TAU;
    float cosTheta = 1.0 - r.y;
    float sinTheta = sqrt(1.0 - cosTheta * cosTheta);
    return vec3(cos(phi) * sinTheta, sin(phi) * sinTheta, cosTheta);
}

// Provided by lith#0281
vec3 cosineWeightedHemisphereDirection(vec2 r) {
    float radius = sqrt(r.y);
    float xOffset = radius * cos(TAU * r.x);
    float yOffset = radius * sin(TAU * r.x);
    float zOffset = sqrt(1.0 - r.y);
    return normalize(vec3(xOffset, yOffset, zOffset));
}

// https://en.wikipedia.org/wiki/Circle_of_confusion#Determining_a_circle_of_confusion_diameter_from_the_object_field
float getCoC(float fragDepth, float cursorDepth) {
    return fragDepth < 0.56 ? 0.0 : abs((FOCAL / APERTURE) * ((FOCAL * (cursorDepth - fragDepth)) / (fragDepth * (cursorDepth - FOCAL)))) * 0.5;
}

vec2 distort(vec2 coords) {
	return coords / (length(coords) * SHADOW_BIAS + (1.0 - SHADOW_BIAS));
}

/* ENCODING */
// Normals encoding / decoding from: https://aras-p.info/texts/CompactNormalStorage.html

const float packingScale = 1.7777;
vec2 encodeNormal(vec3 normal) {
    vec2 enc = normal.xy / (normal.z + 1.0);
    enc /= packingScale;
    return enc * 0.5 + 0.5;
}

vec3 decodeNormal(vec2 enc) {
    vec3 nn = vec3(enc, 0.0) * vec3(vec2(2.0 * packingScale), 0.0) + vec3(vec2(-packingScale), 1.0);
    float g = 2.0 / dot(nn.xyz, nn.xyz);
    return vec3(g * nn.xy, g - 1.0);
}

float pack2x8(vec2 x, float pattern) {
	return dot(floor(255.0 * x + pattern), vec2(1.0 / 65535.0, 256.0 / 65535.0));
}

vec2 unpack2x8(float pack) {
	pack *= 65535.0 / 256.0;
	vec2 xy; xy.y = floor(pack); xy.x = pack - xy.y;
	return vec2(256.0 / 255.0, 1.0 / 255.0) * xy;
}
