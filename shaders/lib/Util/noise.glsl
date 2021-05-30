/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

float rand(vec2 x) {
	return fract(sin(dot(x, vec2(12.9898, 4.1414))) * 43758.5453);
}

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

vec3 hash33(vec3 pos) {
	pos = vec3(dot(pos, vec3(127.1, 311.7, 74.7)),
		  dot(pos, vec3(269.5, 183.3, 246.1)),
		  dot(pos, vec3(113.5, 271.9, 124.6)));

	return fract(sin(pos) * 43758.5453123);
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

float interleavedGradientNoise(vec2 n) {
    float f = 0.06711056 * n.x + 0.00583715 * n.y;
    return fract(52.9829189 * fract(f));
}

/////////////// DENOISER BY BRUTPITT ///////////////
// https://github.com/BrutPitt/glslSmartDeNoise/ //

#define INV_SQRT_OF_2PI 0.39894228040143267793994605993439
#define INV_PI 0.31831
#define RADIUS 8

vec4 smartDeNoise(sampler2D tex, vec2 uv, float sigma, float kSigma, float threshold) {
    float radius = floor(kSigma*sigma + 0.5);
    radius = RADIUS;
    float radQ = radius * radius;
    
    float invSigmaQx2 = 0.5 / (sigma * sigma);     // 1.0 / (sigma^2 * 2.0)
    float invSigmaQx2PI = INV_PI * invSigmaQx2;    // 1.0 / (sqrt(PI) * sigma)
    
    float invThresholdSqx2 = .5 / (threshold * threshold);     // 1.0 / (sigma^2 * 2.0)
    float invThresholdSqrt2PI = INV_SQRT_OF_2PI / threshold;   // 1.0 / (sqrt(2*PI) * sigma)
    
    vec4 centrPx = texture2D(tex, uv);
    float zBuff = 0.0;
    vec4 aBuff = vec4(0.0);
    
    for(float x = -radius; x <= radius; x++) {
        float pt = sqrt(radQ - x * x);  

        for(float y = -pt; y <= pt; y++) {
            vec2 d = vec2(x, y);

            float blurFactor = exp(-dot(d, d) * invSigmaQx2) * invSigmaQx2PI; 
            
            vec4 walkPx = texture2D(tex, uv + d / vec2(viewWidth, viewHeight));

            vec4 dC = walkPx - centrPx;
            float deltaFactor = exp(-dot(dC, dC) * invThresholdSqx2) * invThresholdSqrt2PI * blurFactor;
                                 
            zBuff += deltaFactor;
            aBuff += deltaFactor * walkPx;
        }
    }
    return aBuff / zBuff;
}
