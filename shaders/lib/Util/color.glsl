/*
  Author: Belmu (https://github.com/BelmuTM/)
  */

// I AM NOT THE AUTHOR OF THE TONE MAPPING ALGORITHMS BELOW
// Most sources are: Github, ShaderToy or Discord.

#define TONEMAPPING 4 // [-1 0 1 2 3 4]

float luma(vec3 color) {
    return dot(color, vec3(0.299, 0.587, 0.114));
}

float blendOverlay(float base, float blend) {
    return base < 0.5 ? (2.0 * base * blend) : (1.0 - 2.0 * (1.0 - base ) * (1.0 - blend));
}

vec3 blendOverlay(vec3 base, vec3 blend) {
    return vec3(blendOverlay(base.r, blend.r), blendOverlay(base.g, blend.g), blendOverlay(base.b, blend.b));
}

vec3 blendOverlay(vec3 base, vec3 blend, float opacity) {
	return blendOverlay(base, blend) * opacity + base * (1.0 - opacity);
}

vec3 luma_based_reinhard(vec3 color) {
    float luma = luma(color.rgb);
	float white = 2.0;
	float toneMappedLuma = luma * (1.0 + luma / (white * white)) / (1.0 + luma);
	color *= toneMappedLuma / luma;
	return color;
}

vec3 reinhard_jodie(vec3 color) {
    float luma = luma(color);
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

// Uchimura 2017, "HDR theory and practice"
// Math: https://www.desmos.com/calculator/gslcdxvipg
// Source: https://www.slideshare.net/nikuque/hdr-theory-and-practicce-jp

vec3 uchimura(vec3 x, float P, float a, float m, float l, float c, float b) {
    float l0 = ((P - m) * l) / a;
    float L0 = m - m / a;
    float L1 = m + (1.0 - m) / a;
    float S0 = m + l0;
    float S1 = m + a * l0;
    float C2 = (a * P) / (P - S1);
    float CP = -C2 / P;

    vec3 w0 = vec3(1.0 - smoothstep(0.0, m, x));
    vec3 w2 = vec3(step(m + l0, x));
    vec3 w1 = vec3(1.0 - w0 - w2);

    vec3 T = vec3(m * pow(x / m, vec3(c)) + b);
    vec3 S = vec3(P - (P - S1) * exp(CP * (x - S0)));
    vec3 L = vec3(m + a * (x - m));

    return T * w0 + L * w1 + S * w2;
}

vec3 uchimura(vec3 x) {
    const float P = 1.0;  // max display brightness
    const float a = 1.0;  // contrast
    const float m = 0.22; // linear section start
    const float l = 0.4;  // linear section length
    const float c = 1.33; // black
    const float b = 0.0;  // pedestal

    return uchimura(x, P, a, m, l, c, b);
}

vec3 lottes(vec3 x) {
    const vec3 a = vec3(1.6);
    const vec3 d = vec3(0.977);
    const vec3 hdrMax = vec3(8.0);
    const vec3 midIn = vec3(0.18);
    const vec3 midOut = vec3(0.267);

    const vec3 b =
      (-pow(midIn, a) + pow(hdrMax, a) * midOut) /
      ((pow(hdrMax, a * d) - pow(midIn, a * d)) * midOut);
    const vec3 c =
      (pow(hdrMax, a * d) * pow(midIn, a) - pow(hdrMax, a) * pow(midIn, a * d) * midOut) /
      ((pow(hdrMax, a * d) - pow(midIn, a * d)) * midOut);

    return pow(x, a) / (pow(x, a * d) * b + c);
}

// Originally made by Richard Burgess-Dawson
// Modified by JustTech#2594
vec3 burgess(vec3 color) {
    vec3 maxColor = color * min(vec3(1.0), 1.0 - exp(-1.0 / 0.004 * color)) * 0.8;
    vec3 retColor = (maxColor * (6.2 * maxColor + 0.5)) / (maxColor * (6.2 * maxColor + 1.7) + 0.06);
    return retColor;
}

vec3 vibrance_saturation(vec3 color, float vibrance, float saturation) {
    float luma = luma(color);
    float mn = min(min(color.r, color.g), color.b);
    float mx = max(max(color.r, color.g), color.b);
    float sat = (1.0 - saturate(mx - mn)) * saturate(1.0 - mx) * luma * 5.0;
    vec3 light = vec3((mn + mx) / 2.0);

    color = mix(color, mix(light, color, vibrance), sat);
    color = mix(color, light, (1.0 - light) * (1.0 - vibrance) / 2.0 * abs(vibrance));
    color = mix(vec3(luma), color, saturation);
    return color;
}

vec3 brightness_contrast(vec3 color, float contrast, float brightness) {
    return (color - 0.5) * contrast + 0.5 + brightness;
}

// SRGB to Linear
vec3 decodeSRGB(vec3 screenRGB) {
    vec3 a = screenRGB / 12.92;
    vec3 b = pow((screenRGB + 0.055) / 1.055, vec3(2.4));
    vec3 c = step(vec3(0.04045), screenRGB);
    return mix(a, b, c);
}

// Linear to SRGB
vec3 encodeSRGB(vec3 linearRGB) {
    vec3 a = 12.92 * linearRGB;
    vec3 b = 1.055 * pow(linearRGB, vec3(1.0 / 2.4)) - 0.055;
    vec3 c = step(vec3(0.0031308), linearRGB);
    
    #if TONEMAPPING != 5
        return mix(a, b, c);
    #else
        return screenRGB;
    #endif
}

vec3 srgbToLinear(vec3 srgb) {
    return pow(srgb, vec3(2.2));
}

vec3 linearToSRGB(vec3 linear) {
    #if TONEMAPPING != 4
        return pow(linear, vec3(1.0 / 2.2));
    #else
        return linear;
    #endif
}

vec3 toSRGB(vec3 color) {
	return mix(color * 12.92, 1.055 * pow(color, vec3(1.0 / 2.4)) - 0.055, vec3(greaterThan(color, vec3(0.0031308))));
}

vec3 toLinear(vec3 color) {
	return mix(color / 12.92, pow((color + 0.055) / 1.055, vec3(2.4)), vec3(greaterThan(color, vec3(0.04045))));
}

