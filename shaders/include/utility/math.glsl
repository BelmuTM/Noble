/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* MATH FUNCTIONS */

float maxEps(float x) { return max(EPS, x);       }
float max0(float x)   { return max(0.0, x);       }
vec2  max0(vec2 x)    { return max(vec2(0.0), x); }
vec3  max0(vec3 x)    { return max(vec3(0.0), x); }
vec4  max0(vec4 x)    { return max(vec4(0.0), x); }

float clamp01(float x) { return clamp(x, 0.0, 1.0); }
vec2 clamp01(vec2 x)   { return clamp(x, vec2(0.0), vec2(1.0)); }
vec3 clamp01(vec3 x)   { return clamp(x, vec3(0.0), vec3(1.0)); }
vec4 clamp01(vec4 x)   { return clamp(x, vec4(0.0), vec4(1.0)); }

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

vec3 generateUnitVector(vec2 xy) {
    xy.x *= TAU; xy.y = xy.y * 2.0 - 1.0;
    return vec3(vec2(sin(xy.x), cos(xy.x)) * sqrt(1.0 - xy.y * xy.y), xy.y);
}

vec3 generateCosineVector(vec2 xy) {
    xy.x *= TAU;
    return normalize(vec3(vec2(cos(xy.x), sin(xy.x)) * sqrt(xy.y), sqrt(1.0 - xy.y)));
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

float pack2x8(vec2 x) {
	return dot(floor(255.0 * x + 0.5), vec2(1.0 / 65535.0, 256.0 / 65535.0));
}

vec2 unpack2x8(float pack) {
	pack *= 65535.0 / 256.0;
	vec2 xy; xy.y = floor(pack); xy.x = pack - xy.y;
	return vec2(256.0 / 255.0, 1.0 / 255.0) * xy;
}

float pack2x4(vec2 xy) {
	return dot(floor(15.0 * xy + 0.5), vec2(1.0 / 255.0, 16.0 / 255.0));
}

vec2 unpack2x4(float pack) {
	vec2 xy; xy.x = modf(pack * 255.0 / 16.0, xy.y);
	return xy * vec2(16.0 / 15.0, 1.0 / 15.0);
}
