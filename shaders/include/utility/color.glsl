/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/
/*
    I AM NOT THE AUTHOR OF THE TONE MAPPING ALGORITHMS BELOW
    Most sources are: Github, Shadertoy or Discord.

    Main source for tonemaps:
    https://github.com/dmnsgn/glsl-tone-map
*/

//////////////////////////////////////////////////////////
/*----------------- COLOR CONVERSIONS ------------------*/
//////////////////////////////////////////////////////////


#if TONEMAP == 0
    // AP1 color space -> https://en.wikipedia.org/wiki/Academy_Color_Encoding_System
    float luminance(vec3 color) {
        return dot(color, AP1);
    }
#else
    // REC. 709 -> https://en.wikipedia.org/wiki/Luma_(video)
    float luminance(vec3 color) {
        return dot(color, REC_709);
    }
#endif

// https://www.titanwolf.org/Network/q/bb468365-7407-4d26-8441-730aaf8582b5/x
vec3 linearTosRGB(vec3 linear) {
    vec3 higher = (pow(abs(linear), vec3(1.0 / 2.4)) * 1.055) - 0.055;
    vec3 lower  = linear * 12.92;
    return mix(higher, lower, step(linear, vec3(0.0031308)));
}

vec3 sRGBToLinear(vec3 sRGB) {
    vec3 higher = pow((sRGB + 0.055) / 1.055, vec3(2.4));
    vec3 lower  = sRGB / 12.92;
    return mix(higher, lower, step(sRGB, vec3(0.04045)));
}

const mat3 SRGB_2_XYZ_MAT = (mat3(
    0.4124, 0.3576, 0.1805,
    0.2126, 0.7152, 0.0722,
    0.0193, 0.1192, 0.9505
));

const mat3 XYZ_2_SRGB_MAT = (mat3(
     3.2406,-1.5372,-0.4986,
    -0.9689, 1.8758, 0.0415,
     0.0557,-0.2040, 1.0570
));

const mat3 CONE_RESP_CAT02 = mat3(
	vec3( 0.7328, 0.4296,-0.1624),
	vec3(-0.7036, 1.6975, 0.0061),
	vec3( 0.0030, 0.0136, 0.9834)
);

const mat3 CONE_RESP_BRADFORD = mat3(
	vec3( 0.8951, 0.2664,-0.1614),
	vec3(-0.7502, 1.7135, 0.0367),
	vec3( 0.0389,-0.0685, 1.0296)
);

// https://www.shadertoy.com/view/ltjBWG
const mat3 RGB_2_YCoCg_MAT = mat3(0.25, 0.5,-0.25, 0.5, 0.0, 0.5, 0.25, -0.5,-0.25);
const mat3 YCoCg_2_RGB_MAT = mat3(1.0,  1.0,  1.0, 1.0, 0.0,-1.0, -1.0,  1.0, -1.0);

vec3 linearToYCoCg(vec3 linear) { return RGB_2_YCoCg_MAT * linearTosRGB(linear).rgb; }
vec3 YCoCgToLinear(vec3 YCoCg)  { return sRGBToLinear(YCoCg_2_RGB_MAT * YCoCg).rgb;  }

//////////////////////////////////////////////////////////
/*---------------------- TONEMAPS ----------------------*/
//////////////////////////////////////////////////////////

void whitePreservingReinhard(inout vec3 color, float white) {
	float luma           = luminance(color);
	float toneMappedLuma = luma * (1.0 + luma / (white * white)) / (1.0 + luma);
	color               *= toneMappedLuma / luma;
}

void reinhardJodie(inout vec3 color) {
    float luma = luminance(color);
    vec3 tv    = color / (1.0 + color);
    color      = mix(color / (1.0 + luma), tv, tv);
}

void lottes(inout vec3 color) {
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

    color = pow(color, a) / (pow(color, a * d) * b + c);
}

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

void uchimura(inout vec3 color) {
    const float P = 1.0;  // max display brightness
    const float a = 1.0;  // contrast
    const float m = 0.22; // linear section start
    const float l = 0.4;  // linear section length
    const float c = 1.33; // black
    const float b = 0.0;  // pedestal

    color = uchimura(color, P, a, m, l, c, b);
}

void uncharted2(inout vec3 color) {
	const float A = 0.15;
	const float B = 0.50;
	const float C = 0.10;
	const float D = 0.20;
	const float E = 0.02;
	const float F = 0.30;
	const float W = 11.2;

	color       = ((color * (A * color + C * B) + D * E) / (color * (A * color + B) + D * F)) - E / F;
	float white = ((W * (A * W + C * B) + D * E) / (W * (A * W + B) + D * F)) - E / F;
	color      /= white;
}

// Originally made by Richard Burgess-Dawson
// Modified by https://github.com/TechDevOnGitHub
void burgess(vec3 color) {
    vec3 maxColor = color * min(vec3(1.0), 1.0 - exp(-1.0 / (luminance(color) * 0.1) * color));
    color         = (maxColor * (6.2 * maxColor + 0.5)) / (maxColor * (6.2 * maxColor + 1.7) + 0.06);
}

//////////////////////////////////////////////////////////
/*------------------ COLOR CORRECTION ------------------*/
//////////////////////////////////////////////////////////

// https://www.shadertoy.com/view/lsSXW1
// https://tannerhelland.com/2012/09/18/convert-temperature-rgb-algorithm-code.html
vec3 temperatureToRGB(in float temperature){
    vec3 color;
    temperature = clamp(temperature, 1000, 40000) * 0.01;
    
    if (temperature <= 66) {
        color.r = 1.0;
        color.g = clamp01(0.390081578 * log(temperature) - 0.631841443);
    } else {
    	float t    = temperature - 60;
        color.r = clamp01(1.292936186 * pow(t, -0.133204759));
        color.g = clamp01(1.129890860 * pow(t, -0.075514849));
    }
    
    if(temperature >= 66)      { color.b = 1; }
    else if(temperature <= 19) { color.b = 0; }
    else                       { color.b = clamp01(0.543206789 * log(temperature - 10) - 1.196254089); }

    return sRGBToLinear(color);
}   

// Black body radiation from https://github.com/Jessie-LC/open-source-utility-code/blob/main/advanced/blackbody.glsl
vec3 plancks(in float t, in vec3 lambda) {
    const float h = 6.63e-16; // Planck's constant
    const float c = 3.0e17;   // Speed of light
    const float k = 1.38e-5;  // Boltzmann's constant
    vec3 p1 = (2.0 * h * pow(c, 2.0)) / pow(lambda, vec3(5.0));
    vec3 p2 = exp(h * c / (lambda * k * t)) - vec3(1.0);
    return (p1 / p2) * pow(1e9, 2.0);
}

vec3 blackbody(in float t) {
    vec3 rgb = plancks(t, vec3(660.0, 550.0, 440.0));
         rgb /= max(rgb.x, max(rgb.y, rgb.z)); // Keeping the values below 1.0
    return rgb;
}

/*
    Sources for White Balance:
    https://en.wikipedia.org/wiki/LMS_color_space
    https://en.wikipedia.org/wiki/Von_Kries_coefficient_law
    https://github.com/zombye/spectrum
*/

mat3 chromaticAdaptationMatrix(vec3 source, vec3 destination) {
	vec3 sourceLMS      = source * CONE_RESP_CAT02;
	vec3 destinationLMS = destination * CONE_RESP_CAT02;
	vec3 tmp            = destinationLMS / sourceLMS;

	mat3 vonKries = mat3(
		tmp.x, 0.0, 0.0,
		0.0, tmp.y, 0.0,
		0.0, 0.0, tmp.z
	);

	return (CONE_RESP_CAT02 * vonKries) * inverse(CONE_RESP_CAT02);
}

void whiteBalance(inout vec3 color) {
    vec3 source              = blackbody(WHITE_BALANCE) * SRGB_2_XYZ_MAT;
    vec3 destination         = blackbody(6500.0) * SRGB_2_XYZ_MAT;
    mat3 chromaticAdaptation = SRGB_2_XYZ_MAT * chromaticAdaptationMatrix(source, destination) * XYZ_2_SRGB_MAT;
    color                   *= chromaticAdaptation;
}

void vibrance(inout vec3 color, float intensity) {
    float mn       = minOf3(color);
    float mx       = maxOf3(color);
    float sat      = (1.0 - clamp01(mx - mn)) * clamp01(1.0 - mx) * luminance(color) * 5.0;
    vec3 lightness = vec3((mn + mx) * 0.5);

    // Vibrance
    color = mix(color, mix(lightness, color, intensity), sat);
    // Negative vibrance
    color = mix(color, lightness, (1.0 - lightness) * (1.0 - intensity) * 0.5 * abs(intensity));
}

void saturation(inout vec3 color, float intensity) {
    color = mix(vec3(luminance(color)), color, intensity);
}

void contrast(inout vec3 color, float contrast) {
    color = (color - 0.5) * contrast + 0.5;
}

// http://filmicworlds.com/blog/minimal-color-grading-tools/
void liftGammaGain(inout vec3 color, float lift, float gamma, float gain) {
    vec3 lerpV = clamp01(pow(color, vec3(gamma)));
    color = gain * lerpV + lift * (1.0 - lerpV);
}
