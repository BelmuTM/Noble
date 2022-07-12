/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

// MOST FUNCTIONS HERE ARE NOT MY PROPERTY

// Jodie's dithering
float bayer2(vec2 a) {
    a = floor(a);
    return fract(dot(a, vec2(0.5, a.y * 0.75)));
}

#define bayer4(a)   (bayer2(0.5   * (a))  *  0.25 + bayer2(a))
#define bayer8(a)   (bayer4(0.5   * (a))  *  0.25 + bayer2(a))
#define bayer16(a)  (bayer8(0.5   * (a))  *  0.25 + bayer2(a))
#define bayer32(a)  (bayer16(0.5  * (a))  *  0.25 + bayer2(a))
#define bayer64(a)  (bayer32(0.5  * (a))  *  0.25 + bayer2(a))
#define bayer128(a) (bayer64(0.5  * (a))  *  0.25 + bayer2(a))
#define bayer256(a) (bayer128(0.5 * (a))  *  0.25 + bayer2(a))
#define bayer512(a) (bayer256(0.5 * (a))  *  0.25 + bayer2(a))

const vec2 taaOffsets[8] = vec2[8](
	vec2( 0.125,-0.375),
	vec2(-0.125, 0.375),
	vec2( 0.625, 0.125),
	vec2( 0.375,-0.625),
	vec2(-0.625, 0.625),
	vec2(-0.875,-0.125),
	vec2( 0.375,-0.875),
	vec2( 0.875, 0.875)
);

vec2 taaJitter(vec4 pos) {
    return taaOffsets[framemod] * (pos.w * pixelSize);
}

// Noise distribution: https://www.pcg-random.org/
void pcg(inout uint seed) {
    uint state = seed * 747796405u + 2891336453u;
    uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    seed = (word >> 22u) ^ word;
}

#ifdef STAGE_FRAGMENT
    vec3 blueNoise = texelFetch(noisetex, ivec2(mod(gl_FragCoord, noiseRes)), 0).rgb;

    uint rngState = 185730u * uint(frameCounter) + uint(gl_FragCoord.x + gl_FragCoord.y * viewSize.x);
    float randF() { pcg(rngState); return float(rngState) / float(0xffffffffu); }
#endif

// http://byteblacksmith.com/improvements-to-the-canonical-one-liner-glsl-rand-for-opengl-es-2-0/
float rand(vec2 uv) {
    float dt = dot(uv.xy, vec2(12.9898, 78.233));
    return fract(sin(mod(dt, PI)) * 43758.5453);
}

float hash11(float p) { return fract(sin(p) * 1e4); }

float hash12(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

vec3 hash32(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3     += dot(p3, p3.yxz + 33.33);
    return fract((p3.xxy + p3.yzz) * p3.zyx);
}

vec3 hash33(vec3 p3) {
	p3  = fract(p3 * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yxz + 33.33);
    return fract((p3.xxy + p3.yxx) * p3.zyx);
}

float noise(vec2 uv) {
	vec2 ip = floor(uv);
	vec2 u  = fract(uv);
	u = u * u * (3.0 - 2.0 * u);

	float res = mix(
		mix(hash12(ip), hash12(ip + vec2(1.0, 0.0)), u.x),
		mix(hash12(ip + vec2(0.0, 1.0)), hash12(ip + vec2(1.0, 1.0)), u.x), u.y);
	return res * res;
}

float noise(vec3 uv) {
	const vec3 step = vec3(110.0, 241.0, 171.0);
	vec3 i  = floor(uv);
	vec3 f  = fract(uv);
    float n = dot(i, step);

	vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash11(n + dot(step, vec3(0.0, 0.0, 0.0))), hash11(n + dot(step, vec3(1.0, 0.0, 0.0))), u.x),
                   mix(hash11(n + dot(step, vec3(0.0, 1.0, 0.0))), hash11(n + dot(step, vec3(1.0, 1.0, 0.0))), u.x), u.y),
               mix(mix(hash11(n + dot(step, vec3(0.0, 0.0, 1.0))), hash11(n + dot(step, vec3(1.0, 0.0, 1.0))), u.x),
                   mix(hash11(n + dot(step, vec3(0.0, 1.0, 1.0))), hash11(n + dot(step, vec3(1.0, 1.0, 1.0))), u.x), u.y), u.z);
}

vec2 uniformAnimatedNoise(in vec2 seed) {
    return fract(seed + vec2(GOLDEN_RATIO * frameTimeCounter, (GOLDEN_RATIO + GOLDEN_RATIO) * mod(frameTimeCounter, 100.0)));
}

vec2 uniformNoise(int i, in vec3 seed) {
    return vec2(fract(seed.x + GOLDEN_RATIO * i), fract(seed.y + (GOLDEN_RATIO + GOLDEN_RATIO) * i));
}

// https://www.shadertoy.com/view/Xd23Dh
// From Inigo Quilez: http://iquilezles.org/www/articles/voronoise/voronoise.htm
float voronoise(in vec2 x, int u, int v) {
    vec2 p = floor(x);
    vec2 f = fract(x);

    float k  = 1.0 + 63.0 * pow(1.0 - v, 4.0);
    float va = 0.0, wt = 0.0;

    for(int j= -2; j <= 2; j++) {
        for(int i= -2; i <= 2; i++) {
            vec2  g = vec2(float(i), float(j));
            vec3  o = hash32(p + g) * vec3(u, u, 1.0);
            vec2  r = g - f + o.xy;
            float d = dot(r,r);
            float w = pow(1.0 - smoothstep(0.0, 1.414, sqrt(d)), k);
            va += w * o.z;
            wt += w;
        }
    }

    return va / wt;
}

float worley(vec3 uv, float frequency) {    
    vec3 id = floor(uv);
    vec3 p  = fract(uv);
    
    float minDist = 1e6;
    for(int x = -1; x <= 1; x++) {
        for(int y = -1; y <= 1; y++) {
            for(int z = -1; z <= 1; z++) {
                vec3 offset  = vec3(x, y, z);
            	vec3 height  = hash33(mod(id + offset, vec3(frequency))) * 0.5 + 0.5;
    			     height += offset;
            	vec3 d = p - height;
           		minDist = min(minDist, dot(d, d));
            }
        }
    }
    return 1.0 - minDist;
}

float FBM(vec2 uv, int octaves) {
    float value       = 0.0;
    float frequency   = 2.0;
    float amplitude   = 1.0;
    float lacunarity  = 0.9;
    float persistance = 0.5;

    for(int i = 0; i < octaves; i++) {
        value     += noise(uv * frequency) * amplitude;
        frequency *= lacunarity;
        amplitude *= persistance;
    }
    return value;
}

float FBM(vec3 uv, int octaves) {
    float value       = 0.0;
    float frequency   = 0.35;
    float amplitude   = 1.0;
    float lacunarity  = 0.9;
    float persistance = 0.5;

    for(int i = 0; i < octaves; i++) {
        value     += noise(uv * frequency) * amplitude;
        frequency *= lacunarity;
        amplitude *= persistance;
    }
    return value;
}
