/*
  Author: Belmu (https://github.com/BelmuTM/)
  */

// I AM NOT THE AUTHOR OF THE TONE MAPPING ALGORITHMS BELOW
// Most sources are: Github, ShaderToy or Discord.

// REC. 709 -> https://en.wikipedia.org/wiki/Luma_(video)
float luminance(vec3 color) {
    return dot(color, REC_709);
}

vec3 whitePreservingReinhard(vec3 color) {
	const float white = 10.0;
	float luma = luminance(color);
	float toneMappedLuma = luma * (1.0 + luma / (white * white)) / (1.0 + luma);
	color *= toneMappedLuma / luma;
	return color;
}

vec3 reinhardJodie(vec3 color) {
    float luma = luminance(color);
    vec3 tv = color / (1.0 + color);
    return mix(color / (1.0 + luma), tv, tv);
}

vec3 uncharted2(vec3 color) {
	float A = 0.15;
	float B = 0.50;
	float C = 0.10;
	float D = 0.20;
	float E = 0.02;
	float F = 0.30;
	float W = 11.2;

	color = ((color * (A * color + C * B) + D * E) / (color * (A * color + B) + D * F)) - E / F;
	float white = ((W * (A * W + C * B) + D * E) / (W * (A * W + B) + D * F)) - E / F;
	color /= white;
	return color;
}

// Originally made by Richard Burgess-Dawson
// Modified by JustTech#2594
vec3 burgess(vec3 color) {
    vec3 maxColor = color * min(vec3(1.0), 1.0 - exp(-1.0 / 0.004 * color)) * 0.8;
    return (maxColor * (6.2 * maxColor + 0.5)) / (maxColor * (6.2 * maxColor + 1.7) + 0.06);
}

const mat3 ACESInputMat = mat3(
    0.59719, 0.35458, 0.04823,
    0.07600, 0.90834, 0.01566,
    0.02840, 0.13383, 0.83777
);

const mat3 ACESOutputMat = mat3(
    1.60475, -0.53108, -0.07367,
    -0.10208,  1.10813, -0.00605,
    -0.00327, -0.07276,  1.07602
);

vec3 RRTAndODTFit(vec3 v) {
    vec3 a = v * (v + 0.0245786);
    vec3 b = v * (0.983729 * v + 0.4329510) + 0.238081;
    return a / b;
}

vec3 ACESFitted(vec3 color) {
    return clamp(RRTAndODTFit(color * ACESInputMat) * ACESOutputMat, 0.0, 1.0);
}

vec3 ACESApprox(vec3 x) {
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

vec3 vibranceSaturation(vec3 color, float vibrance, float saturation) {
    float luma = luminance(color);
    float mn   = min(min(color.r, color.g), color.b);
    float mx   = max(max(color.r, color.g), color.b);
    float sat  = (1.0 - clamp01(mx - mn)) * clamp01(1.0 - mx) * luma * 5.0;
    vec3 light = vec3((mn + mx) / 2.0);

    color = mix(color, mix(light, color, vibrance), sat);
    color = mix(color, light, (1.0 - light) * (1.0 - vibrance) / 2.0 * abs(vibrance));
    color = mix(vec3(luma), color, saturation);
    return color;
}

vec3 contrast(vec3 color, float contrast) {
    return color * contrast + (0.5 - contrast * 0.5);
}

// https://www.titanwolf.org/Network/q/bb468365-7407-4d26-8441-730aaf8582b5/x
vec4 linearToSRGB(vec4 linear) {;
    vec4 higher = (pow(abs(linear), vec4(1.0 / 2.4)) * 1.055) - 0.055;
    vec4 lower  = linear * 12.92;
    return mix(higher, lower, step(linear, vec4(0.0031308)));
}

vec4 sRGBToLinear(vec4 sRGB) {
    vec4 higher = pow((sRGB + 0.055) / 1.055, vec4(2.4));
    vec4 lower  = sRGB / 12.92;
    return mix(higher, lower, step(sRGB, vec4(0.04045)));
}

// Adobe RGB (1998) color space matrix from:
// http://www.brucelindbloom.com/index.html?Eqn_RGB_XYZ_Matrix.html
const mat3 RGBtoXYZMatrix = (mat3(
    0.5767309, 0.1855540, 0.1881852,
    0.2973769, 0.6273491, 0.0752741,
    0.0270343, 0.0706872, 0.9911085
));

const mat3 XYZtoRGBMatrix = (mat3(
     2.0413690,-0.5649464,-0.3446944,
    -0.9692660, 1.8760108, 0.0415560,
     0.0134474,-0.1183897, 1.0154096
));

vec3 linearToXYZ(vec3 linear) {
    return RGBtoXYZMatrix * linear;
}

vec3 XYZtoLinear(vec3 XYZ) {
    return XYZtoRGBMatrix * XYZ;
}

// https://www.shadertoy.com/view/ltjBWG
const mat3 RGBToYCoCgMatrix = mat3(0.25, 0.5,-0.25, 0.5, 0.0, 0.5, 0.25, -0.5,-0.25);
const mat3 YCoCgToRGBMatrix = mat3(1.0,  1.0,  1.0, 1.0, 0.0,-1.0, -1.0,  1.0, -1.0);

vec3 RGBToYCoCg(vec3 RGB) {
    return RGBToYCoCgMatrix * RGB;
}

vec3 YCoCgToRGB(vec3 YCoCg) {
    return YCoCgToRGBMatrix * YCoCg;
}

vec3 linearToYCoCg(vec3 linear) {
    vec3 RGB = linearToSRGB(vec4(linear, 1.0)).rgb;
    return isSky(texCoords) ? linear : RGBToYCoCgMatrix * RGB;
}

vec3 YCoCgToLinear(vec3 YCoCg) {
    vec3 RGB = YCoCgToRGBMatrix * YCoCg;
    return isSky(texCoords) ? YCoCg : sRGBToLinear(vec4(RGB, 1.0)).rgb;
}