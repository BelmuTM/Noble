/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

// MOST FUNCTIONS HERE ARE NOT MY PROPERTY

// Noise distribution: https://www.pcg-random.org/
void pcg(inout uint seed) {
    uint state = seed * 747796405u + 2891336453u;
    uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    seed = (word >> 22u) ^ word;
}

#if STAGE == STAGE_FRAGMENT
    uint rngState = 185730U * uint(frameCounter) + uint(gl_FragCoord.x + gl_FragCoord.y * viewResolution.x);
    float randF() { pcg(rngState); return float(rngState) / float(0xffffffffu); }
#endif

// Hammersley
float radicalInverse_VdC(uint bits) {
     bits = (bits << 16u) | (bits >> 16u);
     bits = ((bits & 0x55555555u) << 1u) | ((bits & 0xAAAAAAAAu) >> 1u);
     bits = ((bits & 0x33333333u) << 2u) | ((bits & 0xCCCCCCCCu) >> 2u);
     bits = ((bits & 0x0F0F0F0Fu) << 4u) | ((bits & 0xF0F0F0F0u) >> 4u);
     bits = ((bits & 0x00FF00FFu) << 8u) | ((bits & 0xFF00FF00u) >> 8u);
     return float(bits) * 2.3283064365e-10; // / 0x100000000
}

vec2 hammersley2d(uint i, uint N) {
     return vec2(float(i) / float(N), radicalInverse_VdC(i));
}

// http://byteblacksmith.com/improvements-to-the-canonical-one-liner-glsl-rand-for-opengl-es-2-0/
float rand(vec2 p) {
    float dt = dot(p.xy, vec2(12.9898, 78.233));
    return fract(sin(mod(dt, PI)) * 43758.5453);
}

float noise(vec2 p) {
	vec2 ip = floor(p);
	vec2 u = fract(p);
	u = u * u * (3.0 - 2.0 * u);

	float res = mix(
		mix(rand(ip), rand(ip + vec2(1.0, 0.0)), u.x),
		mix(rand(ip + vec2(0.0, 1.0)), rand(ip + vec2(1.0, 1.0)), u.x), u.y);
	return res * res;
}

float FBM(vec2 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;

    for(int i = 0; i < octaves; i++) {
        value += amplitude * noise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

vec2 uniformAnimatedNoise(in vec2 seed) {
    return fract(seed + vec2(GOLDEN_RATIO * frameTimeCounter, (GOLDEN_RATIO + GOLDEN_RATIO) * mod(frameTimeCounter, 100.0)));
}

vec2 uniformNoise(int i, in vec3 seed) {
    return vec2(fract(seed.x + GOLDEN_RATIO * i), fract(seed.y + (GOLDEN_RATIO + GOLDEN_RATIO) * i));
}

// Gold Noise ©2015 dcerisano@standard3d.com
float goldNoise(vec2 xy, int seed){
    return fract(tan(distance(xy * GOLDEN_RATIO, xy) * float(seed)) * xy.x);
}

vec3 hash32(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3     += dot(p3, p3.yxz + 33.33);
    return fract((p3.xxy + p3.yzz) * p3.zyx);
}

//	<https://www.shadertoy.com/view/Xd23Dh>
//	by inigo quilez <http://iquilezles.org/www/articles/voronoise/voronoise.htm>
vec2 voronoise(in vec2 p, float u, float v) {
	float k = 1.0 + 63.0 * pow(1.0 - v, 6.0);
    vec2 i = floor(p);
    vec2 f = fract(p);
	vec2 a = vec2(0.0, 0.0);

    for(int y = -2; y <= 2; y++) {
        for(int x = -2; x <= 2; x++) {

            vec2 g = vec2(x, y);
		    vec3 o = hash32(i + g) * vec3(u, u, 1.0);
		    vec2 d = g - f + o.xy;
		    float w = pow(1.0 - smoothstep(0.0, 1.414, length(d)), k);
		    a += vec2(o.z * w, w);
        }
    }
    return a;
}
