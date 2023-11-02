/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

/*
    [Credits]
        Jessie     - providing shell intersection function and other utility functions (https://github.com/Jessie-LC/open-source-utility-code/blob/main/simple/misc.glsl)
        sixthsurge - help with encoding functions (https://github.com/sixthsurge)

    [References]:
        Perlin, K. (2002). Improving Noise. https://mrl.cs.nyu.edu/~perlin/paper445.pdf
        Fisher et al. (2003). Gaussian Smoothing. https://homepages.inf.ed.ac.uk/rbf/HIPR2/gsmooth.htm
        Cook, D., J. (2009). Stand-alone error function erf(x). https://www.johndcook.com/blog/2009/01/19/stand-alone-error-function-erf/
        Giles, M. (2011). Approximating the erfinv function. https://people.maths.ox.ac.uk/gilesm/files/gems_erfinv.pdf
        Lagarde, S. (2014). Inverse trigonometric functions GPU optimization for AMD GCN architecture. https://seblagarde.wordpress.com/2014/12/01/inverse-trigonometric-functions-gpu-optimization-for-amd-gcn-architecture/
        Cigolle et al. (2014). Survey of Efficient Representations for Independent Unit Vectors. https://jcgt.org/published/0003/02/01/
        Wikipedia. (2022). Rodrigues' rotation formula. https://en.wikipedia.org/wiki/Rodrigues%27_rotation_formula
*/

//////////////////////////////////////////////////////////
/*--------------------- FAST MATH ----------------------*/
//////////////////////////////////////////////////////////

float maxEps(float x) { return max(EPS, x);       }
float max0(float x)   { return max(0.0, x);       }
vec2  max0(vec2 x)    { return max(vec2(0.0), x); }
vec3  max0(vec3 x)    { return max(vec3(0.0), x); }
vec4  max0(vec4 x)    { return max(vec4(0.0), x); }

float saturate(float x) { return clamp(x, 0.0, 1.0);             }
vec2  saturate(vec2 x)  { return clamp(x, vec2(0.0), vec2(1.0)); }
vec3  saturate(vec3 x)  { return clamp(x, vec3(0.0), vec3(1.0)); }
vec4  saturate(vec4 x)  { return clamp(x, vec4(0.0), vec4(1.0)); }

float clamp16(float x) { return clamp(x, 0.0, maxFloat16);             }
vec2  clamp16(vec2 x)  { return clamp(x, vec2(0.0), vec2(maxFloat16)); }
vec3  clamp16(vec3 x)  { return clamp(x, vec3(0.0), vec3(maxFloat16)); }
vec4  clamp16(vec4 x)  { return clamp(x, vec4(0.0), vec4(maxFloat16)); }

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

float pow10(float x) { return pow(10, x);         }
vec2  pow10(vec2 x)  { return pow(vec2(10.0), x); }
vec3  pow10(vec3 x)  { return pow(vec3(10.0), x); }
vec4  pow10(vec4 x)  { return pow(vec4(10.0), x); }

float log10(float x) { return log(x) / log(10.0);       }
vec2  log10(vec2 x)  { return log(x) / log(vec2(10.0)); }
vec3  log10(vec3 x)  { return log(x) / log(vec3(10.0)); }
vec4  log10(vec4 x)  { return log(x) / log(vec4(10.0)); }

float minOf(vec2 x) { return min(x.x, x.y);                     }
float minOf(vec3 x) { return min(x.x, min(x.y, x.z));           }
float minOf(vec4 x) { return min(min(x.x, x.y), min(x.z, x.w)); }

float maxOf(vec2 x) { return max(x.x, x.y);                     }
float maxOf(vec3 x) { return max(x.x, max(x.y, x.z));           }
float maxOf(vec4 x) { return max(max(x.x, x.y), max(x.z, x.w)); }

float rcp(int x)   { return 1.0 / float(x); }
float rcp(float x) { return 1.0 / x;        }
vec2  rcp(vec2 x)  { return 1.0 / x;        }
vec3  rcp(vec3 x)  { return 1.0 / x;        }
vec4  rcp(vec4 x)  { return 1.0 / x;        }

float quintic(float edge0, float edge1, float x) {
    x = saturate((x - edge0) / (edge1 - edge0));
    return x * x * x * (x * (x * 6.0 - 15.0) + 10.0);
}

float linearStep(float edge0, float edge1, float x) {
    return saturate((x - edge0) / (edge1 - edge0));
}

// max absolute error 9.0x10^-3
// Eberly's polynomial degree 1 - respect bounds
// input [-1, 1] and output [0, PI]
float fastAcos(in float inX) { 
    float x = abs(inX); 
    float res = -0.156583 * x + HALF_PI; 
    res *= sqrt(1.0 - x); 
    return (inX >= 0) ? res : PI - res; 
}

// Same cost as Acos + 1 FR
// Same error
// input [-1, 1] and output [-PI/2, PI/2]
float fastAsin(float x) {
    return HALF_PI - fastAcos(x);
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

float lengthSqr    (vec2 x) { return dot(x, x);              }
float lengthSqr    (vec3 x) { return dot(x, x);              }
float fastRcpLength(vec3 x) { return inversesqrt(dot(x, x)); }
float fastLength   (vec3 x) { return sqrt(dot(x, x));        }

// Fast square root approximations
// https://www.shadertoy.com/view/wlyXRt
float sqrtNewton   (float x, float guess) { return 0.5 * (guess + x / guess);               }
float invSqrtNewton(float x, float guess) { return guess * (1.5 - 0.5 * x * guess * guess); }

float fastSqrt  (float x) { return uintBitsToFloat((floatBitsToUint(x) >> 1) + 0x1FC00000u); }
float fastSqrtN1(float x) { return sqrtNewton(x, fastSqrt(x));                               }

float fastInvSqrt  (float x) { return uintBitsToFloat(0x5F400000u - (floatBitsToUint(x) >> 1)); }
float fastInvSqrtN1(float x) { return invSqrtNewton(x, fastInvSqrt(x));                         }

float remap(float x, float oldLow, float oldHigh, float newLow, float newHigh) {
    return newLow + (x - oldLow) * (newHigh - newLow) / (oldHigh - oldLow);
}

//////////////////////////////////////////////////////////
/*------------------- INTERSECTIONS --------------------*/
//////////////////////////////////////////////////////////

vec2 intersectSphere(vec3 origin, vec3 direction, float radius) {
	float b = dot(origin, direction);
	float c = dot(origin, origin) - radius * radius;
	float d = b * b - c;
	if(d < 0.0) return vec2(-1.0, -1.0);
	d = sqrt(d);
	return vec2(-b - d, -b + d);
}

vec2 intersectSphericalShell(vec3 origin, vec3 direction, float innerSphereRadius, float outerSphereRadius) {
    vec2 innerSphereDists = intersectSphere(origin, direction, innerSphereRadius);
    vec2 outerSphereDists = intersectSphere(origin, direction, outerSphereRadius);

    bool innerSphereIntersected = innerSphereDists.y >= 0.0;
    bool outerSphereIntersected = outerSphereDists.y >= 0.0;

    if(!outerSphereIntersected) return vec2(-1.0);

    vec2 dists;
    dists.x = innerSphereIntersected && innerSphereDists.x < 0.0 ? innerSphereDists.y : max0(outerSphereDists.x);
    dists.y = innerSphereIntersected && innerSphereDists.x > 0.0 ? innerSphereDists.x : outerSphereDists.y;
    return dists;
}

//////////////////////////////////////////////////////////
/*---------------- SPHERICAL PROJECTION ----------------*/
//////////////////////////////////////////////////////////

vec2 projectSphere(vec3 direction) {
    float longitude = atan(-direction.x, -direction.z);
    float latitude  = fastAcos(direction.y);

    return vec2(longitude * rcp(TAU) + 0.5, latitude * RCP_PI);
}

vec3 unprojectSphere(vec2 coords) {
    float latitude = coords.y * PI;
    return vec3(sincos(coords.x * TAU) * sin(latitude), cos(latitude)).xzy;
}

//////////////////////////////////////////////////////////
/*--------------------- ROTATIONS ----------------------*/
//////////////////////////////////////////////////////////

vec3 rotate(vec3 vector, vec3 axis, float angle) {
	vec2 sc = sincos(radians(angle));
	return sc.y * vector + sc.x * cross(axis, vector) + (1.0 - sc.y) * dot(axis, vector) * axis;
}

vec3 rotate(vec3 vector, vec3 from, vec3 to) {
	float cosTheta = dot(from, to);
	if(abs(cosTheta) >= 0.9999) { return cosTheta < 0.0 ? -vector : vector; }
	vec3 axis = normalize(cross(from, to));

	vec2 sc = vec2(sqrt(1.0 - cosTheta * cosTheta), cosTheta);
	return sc.y * vector + sc.x * cross(axis, vector) + (1.0 - sc.y) * dot(axis, vector) * axis;
}

//////////////////////////////////////////////////////////
/*---------------- VECTOR MANIPULATION -----------------*/
//////////////////////////////////////////////////////////

vec3 generateUnitVector(vec2 xy) {
    xy.x *= TAU; xy.y = 2.0 * xy.y - 1.0;
    return vec3(sincos(xy.x) * sqrt(1.0 - xy.y * xy.y), xy.y);
}

vec3 generateCosineVector(vec3 vector, vec2 xy) {
    return normalize(vector + generateUnitVector(xy));
}

vec3 generateConeVector(vec3 vector, vec2 xy, float angle) {
    xy.x *= TAU;
    float cosAngle = cos(angle);
    xy.y = xy.y * (1.0 - cosAngle) + cosAngle;
    vec3 sphereCap = vec3(vec2(cos(xy.x), sin(xy.x)) * sqrt(1.0 - xy.y * xy.y), xy.y);
    return rotate(sphereCap, vec3(0.0, 0.0, 1.0), vector);
}

float coneAngleToSolidAngle(float x) { return TAU * (1.0 - cos(x));      }
float solidAngleToConeAngle(float x) { return fastAcos(1.0 - (x) / TAU); }

//////////////////////////////////////////////////////////
/*-------------------- DISTRIBUTION --------------------*/
//////////////////////////////////////////////////////////

vec2 vogelDisk(float i, float n, float phi) {
    float r     = sqrt(i + phi) / n;
    float theta = i * GOLDEN_ANGLE;
    return sincos(r * theta);
}

vec2 diskSampling(float i, float n, float phi) {
    float theta = (i + phi) / n; 
    return sincos(theta * TAU * n * GOLDEN_ANGLE) * sqrt(phi);
}

float gaussianDistribution1D(float x, float sigma) {
    return (1.0 / (sqrt(TAU) * sigma)) * exp(-pow2(x) / (2.0 * sigma * sigma));
}

float gaussianDistribution2D(vec2 xy, float sigma) {
    return (1.0 / (TAU * sigma * sigma)) * exp(-dot(xy, xy) / (2.0 * sigma * sigma));
}

//////////////////////////////////////////////////////////
/*---------------------- ENCODING ----------------------*/
//////////////////////////////////////////////////////////

const mat3x3 encodingMatrix = mat3x3(
    0.2209, 0.3390, 0.4184,
    0.1138, 0.6780, 0.7319,
    0.0102, 0.1130, 0.2969
);

const mat3x3 decodingMatrix = mat3x3(
     6.0013,-2.7000,-1.7995,
    -1.3320, 3.1029,-5.7720,
     0.3007,-1.0880, 5.6268
);

vec4 logLuvEncode(in vec3 value) {
    vec4 encoded;
    vec3 Xp_Y_XYZp = max(encodingMatrix * value, vec3(1e-6));
    encoded.xy = Xp_Y_XYZp.xy / Xp_Y_XYZp.z;
    float Le = 2.0 * log2(Xp_Y_XYZp.y) + 127.0;
    encoded.w = fract(Le);
    encoded.z = (Le - (floor(encoded.w * 255.0)) / 255.0) / 255.0;
    return encoded;
}

vec3 logLuvDecode(in vec4 encoded) {
    float Le = encoded.z * 255.0 + encoded.w;
    vec3 Xp_Y_XYZp;
    Xp_Y_XYZp.y = exp2((Le - 127.0) * 0.5);
    Xp_Y_XYZp.z = Xp_Y_XYZp.y / encoded.y;
    Xp_Y_XYZp.x = encoded.x * Xp_Y_XYZp.z;
    return max0(decodingMatrix * Xp_Y_XYZp);
}

uint packUnormArb(vec4 data, const uvec4 bits) {
    vec4 mul = exp2(vec4(bits)) - 1.0;

    uvec4 shift   = uvec4(0, bits.x, bits.x + bits.y, bits.x + bits.y + bits.z);
    uvec4 shifted = uvec4(data * mul + 0.5) << shift;

    return shifted.x | shifted.y | shifted.z | shifted.w;
}

vec4 unpackUnormArb(uint pack, const uvec4 bits) {
    uvec4 maxValue  = uvec4(exp2(bits) - 1);
    uvec4 shift     = uvec4(0, bits.x, bits.x + bits.y, bits.x + bits.y + bits.z);
    uvec4 unshifted = uvec4(pack) >> shift;
          unshifted = unshifted & maxValue;

    return vec4(unshifted) * 1.0 / vec4(maxValue);
}

vec2 encodeUnitVector(vec3 v) {
	vec2 encoded = v.xy / (abs(v.x) + abs(v.y) + abs(v.z));
	     encoded = (v.z <= 0.0) ? ((1.0 - abs(encoded.yx)) * signNonZero(encoded)) : encoded;
    
	return 0.5 * encoded + 0.5;
}

vec3 decodeUnitVector(vec2 encoded) {
	encoded = 2.0 * encoded - 1.0;
	vec3 v  = vec3(encoded.xy, 1.0 - abs(encoded.x) - abs(encoded.y));
	if(v.z < 0.0) v.xy = (1.0 - abs(v.yx)) * signNonZero(v.xy);
	return normalize(v);
}
