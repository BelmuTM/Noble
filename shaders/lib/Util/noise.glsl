/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

const vec2 poissonDisk[64] = {
	vec2( -0.04117257, -0.1597612 ),
	vec2( 0.06731031, -0.4353096 ),
	vec2( -0.206701, -0.4089882 ),
	vec2( 0.1857469, -0.2327659 ),
	vec2( -0.2757695, -0.159873 ),
	vec2( -0.2301117, 0.1232693 ),
	vec2( 0.05028719, 0.1034883 ),
	vec2( 0.236303, 0.03379251 ),
	vec2( 0.1467563, 0.364028 ),
	vec2( 0.516759, 0.2052845 ),
	vec2( 0.2962668, 0.2430771 ),
	vec2( 0.3650614, -0.1689287 ),
	vec2( 0.5764466, -0.07092822 ),
	vec2( -0.5563748, -0.4662297 ),
	vec2( -0.3765517, -0.5552908 ),
	vec2( -0.4642121, -0.157941 ),
	vec2( -0.2322291, -0.7013807 ),
	vec2( -0.05415121, -0.6379291 ),
	vec2( -0.7140947, -0.6341782 ),
	vec2( -0.4819134, -0.7250231 ),
	vec2( -0.7627537, -0.3445934 ),
	vec2( -0.7032605, -0.13733 ),
	vec2( 0.8593938, 0.3171682 ),
	vec2( 0.5223953, 0.5575764 ),
	vec2( 0.7710021, 0.1543127 ),
	vec2( 0.6919019, 0.4536686 ),
	vec2( 0.3192437, 0.4512939 ),
	vec2( 0.1861187, 0.595188 ),
	vec2( 0.6516209, -0.3997115 ),
	vec2( 0.8065675, -0.1330092 ),
	vec2( 0.3163648, 0.7357415 ),
	vec2( 0.5485036, 0.8288581 ),
	vec2( -0.2023022, -0.9551743 ),
	vec2( 0.165668, -0.6428169 ),
	vec2( 0.2866438, -0.5012833 ),
	vec2( -0.5582264, 0.2904861 ),
	vec2( -0.2522391, 0.401359 ),
	vec2( -0.428396, 0.1072979 ),
	vec2( -0.06261792, 0.3012581 ),
	vec2( 0.08908027, -0.8632499 ),
	vec2( 0.9636437, 0.05915006 ),
	vec2( 0.8639213, -0.309005 ),
	vec2( -0.03422072, 0.6843638 ),
	vec2( -0.3734946, -0.8823979 ),
	vec2( -0.3939881, 0.6955767 ),
	vec2( -0.4499089, 0.4563405 ),
	vec2( 0.07500362, 0.9114207 ),
	vec2( -0.9658601, -0.1423837 ),
	vec2( -0.7199838, 0.4981934 ),
	vec2( -0.8982374, 0.2422346 ),
	vec2( -0.8048639, 0.01885651 ),
	vec2( -0.8975322, 0.4377489 ),
	vec2( -0.7135055, 0.1895568 ),
	vec2( 0.4507209, -0.3764598 ),
	vec2( -0.395958, -0.3309633 ),
	vec2( -0.6084799, 0.02532744 ),
	vec2( -0.2037191, 0.5817568 ),
	vec2( 0.4493394, -0.6441184 ),
	vec2( 0.3147424, -0.7852007 ),
	vec2( -0.5738106, 0.6372389 ),
	vec2( 0.5161195, -0.8321754 ),
	vec2( 0.6553722, -0.6201068 ),
	vec2( -0.2554315, 0.8326268 ),
	vec2( -0.5080366, 0.8539945 )
};

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
    float radius = round(kSigma*sigma);
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
