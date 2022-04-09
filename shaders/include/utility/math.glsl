/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

//////////////////////////////////////////////////////////
/*--------------------- FAST MATH ----------------------*/
//////////////////////////////////////////////////////////

float maxEps(float x) { return max(EPS, x);       }
float max0(float x)   { return max(0.0, x);       }
vec2  max0(vec2 x)    { return max(vec2(0.0), x); }
vec3  max0(vec3 x)    { return max(vec3(0.0), x); }
vec4  max0(vec4 x)    { return max(vec4(0.0), x); }

float clamp01(float x) { return clamp(x, 0.0, 1.0);             }
vec2  clamp01(vec2 x)  { return clamp(x, vec2(0.0), vec2(1.0)); }
vec3  clamp01(vec3 x)  { return clamp(x, vec3(0.0), vec3(1.0)); }
vec4  clamp01(vec4 x)  { return clamp(x, vec4(0.0), vec4(1.0)); }

float clamp16(float x) { return clamp(x, 0.0, maxVal16);             }
vec2  clamp16(vec2 x)  { return clamp(x, vec2(0.0), vec2(maxVal16)); }
vec3  clamp16(vec3 x)  { return clamp(x, vec3(0.0), vec3(maxVal16)); }
vec4  clamp16(vec4 x)  { return clamp(x, vec4(0.0), vec4(maxVal16)); }

float pow2(float x) { return x*x; }
vec2  pow2(vec2 x)  { return x*x; }
vec3  pow2(vec3 x)  { return x*x; }
vec4  pow2(vec4 x)  { return x*x; }

float pow3(float x) { return pow2(x)*x; }
vec2  pow3(vec2 x)  { return pow2(x)*x; }
vec3  pow3(vec3 x)  { return pow2(x)*x; }
vec4  pow3(vec4 x)  { return pow2(x)*x; }

float pow4(float x) { return pow3(x)*x; }
vec2  pow4(vec2 x)  { return pow3(x)*x; }
vec3  pow4(vec3 x)  { return pow3(x)*x; }
vec4  pow4(vec4 x)  { return pow3(x)*x; }

float pow5(float x) { return pow4(x)*x; }
vec2  pow5(vec2 x)  { return pow4(x)*x; }
vec3  pow5(vec3 x)  { return pow4(x)*x; }
vec4  pow5(vec4 x)  { return pow4(x)*x; }

float pow10(float x) { return pow(10, x); }
vec2  pow10(vec2 x)  { return pow(vec2(10.0), x); }
vec3  pow10(vec3 x)  { return pow(vec3(10.0), x); }
vec4  pow10(vec4 x)  { return pow(vec4(10.0), x); }

float log10(float x) { return log(x) / log(10.0);       }
vec2  log10(vec2 x)  { return log(x) / log(vec2(10.0)); }
vec3  log10(vec3 x)  { return log(x) / log(vec3(10.0)); }
vec4  log10(vec4 x)  { return log(x) / log(vec4(10.0)); }

float minOf2(vec2 x) { return min(x.x, x.y);                     }
float minOf3(vec3 x) { return min(x.x, min(x.y, x.z));           }
float minOf4(vec4 x) { return min(min(x.x, x.y), min(x.z, x.w)); }

float maxOf2(vec2 x) { return max(x.x, x.y);                     }
float maxOf3(vec3 x) { return max(x.x, max(x.y, x.z));           }
float maxOf4(vec4 x) { return max(max(x.x, x.y), max(x.z, x.w)); }

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

vec2 sincos(float x) {
    return vec2(sin(x), cos(x));
}

vec2 signNonZero(vec2 v) {
	return vec2((v.x >= 0.0) ? 1.0 : -1.0, (v.y >= 0.0) ? 1.0 : -1.0);
}

float cubeLength(vec2 v) {
    return pow(pow3(abs(v.x)) + pow3(abs(v.y)), 1.0 / 3.0);
}

float lengthSqr(vec3 x) {
    return dot(x, x);
}

//////////////////////////////////////////////////////////
/*------------------------ MISC ------------------------*/
//////////////////////////////////////////////////////////

vec2 intersectSphere(vec3 rayOrigin, vec3 rayDir, float radius) {
	float b = dot(rayOrigin, rayDir);
	float c = dot(rayOrigin, rayOrigin) - radius * radius;
	float d = b * b - c;
	if(d < 0.0) return vec2(-1.0, -1.0);
	d = sqrt(d);
	return vec2(-b - d, -b + d);
}

// Intersection method from Jessie#7257
vec2 intersectSphericalShell(vec3 rayOrigin, vec3 rayDir, float innerSphereRad, float outerSphereRad) {
    vec2 innerSphereDists = intersectSphere(rayOrigin, rayDir, innerSphereRad);
    vec2 outerSphereDists = intersectSphere(rayOrigin, rayDir, outerSphereRad);

    bool innerSphereIntersected = innerSphereDists.y >= 0.0;
    bool outerSphereIntersected = outerSphereDists.y >= 0.0;

    if(!outerSphereIntersected) return vec2(-1.0);

    vec2 dists;
    dists.x = innerSphereIntersected && innerSphereDists.x < 0.0 ? innerSphereDists.y : max0(outerSphereDists.x);
    dists.y = innerSphereIntersected && innerSphereDists.x > 0.0 ? innerSphereDists.x : outerSphereDists.y;

    return dists;
}

float remap(float x, float oldLow, float oldHigh, float newLow, float newHigh) {
    return newLow + (x - oldLow) * (newHigh - newLow) / (oldHigh - oldLow);
}

vec2 projectSphere(vec3 direction) {
    float longitude = atan(-direction.x, -direction.z);
    float latitude  = acos(direction.y);

    return vec2(longitude * (1.0 / TAU) + 0.5, latitude * INV_PI);
}

vec3 unprojectSphere(vec2 coord) {
    float latitude = coord.y * PI;
    return vec3(sincos(coord.x * TAU) * sin(latitude), cos(latitude)).xzy;
}

vec3 generateUnitVector(vec2 xy) {
    xy.x *= TAU; xy.y = 2.0 * xy.y - 1.0;
    return vec3(sincos(xy.x) * sqrt(1.0 - xy.y * xy.y), xy.y);
}

vec3 generateCosineVector(vec3 vector, vec2 xy) {
    return normalize(vector + generateUnitVector(xy));
}

vec2 vogelDisk(float i, float n, float phi) {
    float r     = sqrt(i + phi) / n;
    float theta = i * GOLDEN_ANGLE;
    return sincos(r * theta);
}

vec2 diskSampling(float i, float n, float phi){
    float theta = (i + phi) / n; 
    return sincos(theta * TAU * n * GOLDEN_ANGLE) * theta;
}

// https://homepages.inf.ed.ac.uk/rbf/HIPR2/gsmooth.htm
float gaussianDistrib1D(float x, float sigma) {
    return (1.0 / (sqrt(TAU) * sigma)) * exp(-pow2(x) / (2.0 * pow2(sigma)));
}

float gaussianDistrib2D(vec2 xy, float sigma) {
    return (1.0 / (TAU * pow2(sigma))) * exp(-dot(xy, xy) / (2.0 * pow2(sigma)));
}

//////////////////////////////////////////////////////////
/*---------------------- ENCODING ----------------------*/
//////////////////////////////////////////////////////////

// Thanks to SixthSurge#3922 for redirecting me to those encoding functions
// http://jcgt.org/published/0003/02/01/

vec2 encodeUnitVector(vec3 v) {
	vec2 enc = v.xy * (1.0 / (abs(v.x) + abs(v.y) + abs(v.z)));
	enc      = (v.z <= 0.0) ? ((1.0 - abs(enc.yx)) * signNonZero(enc)) : enc;
    
	return 0.5 * enc + 0.5;
}

vec3 decodeUnitVector(vec2 enc) {
	enc    = 2.0 * enc - 1.0;
	vec3 v = vec3(enc.xy, 1.0 - abs(enc.x) - abs(enc.y));
	if(v.z < 0.0) v.xy = (1.0 - abs(v.yx)) * signNonZero(v.xy);
	return normalize(v);
}

float packUnorm2x4(vec2 xy) {
	return dot(floor(15.0 * xy + 0.5), vec2(1.0 / maxVal8, 16.0 / maxVal8));
}

vec2 unpackUnorm2x4(float pack) {
	vec2 xy; xy.x = modf(pack * maxVal8 / 16.0, xy.y);
	return xy * vec2(16.0 / 15.0, 1.0 / 15.0);
}

float packUnorm2x8(vec2 xy) {
	return dot(floor(maxVal8 * xy + 0.5), vec2(1.0 / maxVal16, 256.0 / maxVal16));
}

vec2 unpackUnorm2x8(float pack) {
	vec2 xy; xy.x = modf(pack * maxVal16 / 256.0, xy.y);
	return xy * vec2(256.0 / maxVal8, 1.0 / maxVal8);
}

//////////////////////////////////////////////////////////
/*---------------------- BICUBIC -----------------------*/
//////////////////////////////////////////////////////////

// Provided by swr#1793

vec4 cubic(float v) {
    vec4 n  = vec4(1.0, 2.0, 3.0, 4.0) - v;
    vec4 s  = pow3(n);
    float x = s.x;
    float y = s.y - 4.0 * s.x;
    float z = s.z - 4.0 * s.y + 6.0 * s.x;
    float w = 6.0 - x - y - z;
    return vec4(x, y, z, w) * (1.0 / 6.0);
}
 
vec4 textureBicubic(sampler2D tex, vec2 texCoords) {
    vec2 texSize    = textureSize(tex, 0);
    vec2 invTexSize = 1.0 / texSize;
 
    texCoords = texCoords * texSize - 0.5;
 
    vec2 fxy   = fract(texCoords);
    texCoords -= fxy;
 
    vec4 xcubic = cubic(fxy.x);
    vec4 ycubic = cubic(fxy.y);
 
    vec4 c = texCoords.xxyy + vec2(-0.5, +1.5).xyxy;
 
    vec4 s      = vec4(xcubic.xz + xcubic.yw, ycubic.xz + ycubic.yw);
    vec4 offset = c + vec4(xcubic.yw, ycubic.yw) / s;
 
    offset *= invTexSize.xxyy;
 
    vec4 sample0 = texture(tex, offset.xz);
    vec4 sample1 = texture(tex, offset.yz);
    vec4 sample2 = texture(tex, offset.xw);
    vec4 sample3 = texture(tex, offset.yw);
 
    float sx = s.x / (s.x + s.y);
    float sy = s.z / (s.z + s.w);
 
    return mix(
       mix(sample3, sample2, sx), mix(sample1, sample0, sx)
    , sy);
}
