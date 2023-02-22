/***********************************************/
/*          Copyright (C) 2022 Belmu           */
/*       GNU General Public License V3.0       */
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
/*------------------ COLOR MATRICES --------------------*/
//////////////////////////////////////////////////////////

const mat3 SRGB_2_XYZ_MAT = mat3(
	0.4124564, 0.3575761, 0.1804375,
	0.2126729, 0.7151522, 0.0721750,
	0.0193339, 0.1191920, 0.9503041
);

const mat3 XYZ_2_SRGB_MAT = mat3(
	 3.2409699419,-1.5373831776,-0.4986107603,
	-0.9692436363, 1.8759675015, 0.0415550574,
	 0.0556300797,-0.2039769589, 1.0569715142
);

const mat3 XYZ_2_AP0_MAT = mat3(
	 1.0498110175, 0.0000000000,-0.0000974845,
	-0.4959030231, 1.3733130458, 0.0982400361,
	 0.0000000000, 0.0000000000, 0.9912520182
);

const mat3 XYZ_2_AP1_MAT = mat3(
	 1.6410233797,-0.3248032942,-0.2364246952,
	-0.6636628587, 1.6153315917, 0.0167563477,
	 0.0117218943,-0.0082844420, 0.9883948585
);

const mat3 AP0_2_XYZ_MAT = mat3(
	0.9525523959, 0.0000000000, 0.0000936786,
	0.3439664498, 0.7281660966,-0.0721325464,
	0.0000000000, 0.0000000000, 1.0088251844
);

const mat3 AP1_2_XYZ_MAT = mat3(
	 0.6624541811, 0.1340042065, 0.1561876870,
	 0.2722287168, 0.6740817658, 0.0536895174,
	-0.0055746495, 0.0040607335, 1.0103391003
);

const mat3 AP0_2_AP1_MAT = mat3(
	 1.4514393161,-0.2365107469,-0.2149285693,
	-0.0765537734, 1.1762296998,-0.0996759264,
	 0.0083161484,-0.0060324498, 0.9977163014
);

const mat3 AP1_2_AP0_MAT = mat3(
	 0.6954522414, 0.1406786965, 0.1638690622,
	 0.0447945634, 0.8596711185, 0.0955343182,
    -0.0055258826, 0.0040252103, 1.0015006723
);

const mat3 D60_2_D65_CAT = mat3(
	 0.98722400,-0.00611327, 0.01595330,
	-0.00759836, 1.00186000, 0.00533002,
	 0.00307257,-0.00509595, 1.08168000
);

const mat3 D65_2_D60_CAT = mat3(
	 1.01303000, 0.00610531,-0.01497100,
	 0.00769823, 0.99816500,-0.00503203,
	-0.00284131, 0.00468516, 0.92450700
);

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

const vec3 AP1_RGB2Y = vec3(0.2722287168, 0.6740817658, 0.0536895174); // Desaturation Coefficients

const mat3 SRGB_2_AP1        = SRGB_2_XYZ_MAT * D65_2_D60_CAT * XYZ_2_AP1_MAT;
const mat3 SRGB_2_AP1_ALBEDO = SRGB_2_XYZ_MAT * XYZ_2_AP1_MAT;

// https://www.shadertoy.com/view/ltjBWG
const mat3 SRGB_2_YCoCg_MAT = mat3(0.25, 0.5,-0.25, 0.5, 0.0, 0.5, 0.25, -0.5,-0.25);
const mat3 YCoCg_2_SRGB_MAT = mat3(1.0,  1.0,  1.0, 1.0, 0.0,-1.0, -1.0,  1.0, -1.0);

//////////////////////////////////////////////////////////
/*----------------- COLOR CONVERSIONS ------------------*/
//////////////////////////////////////////////////////////

#if TONEMAP == 0
    // AP1 color space -> https://en.wikipedia.org/wiki/Academy_Color_Encoding_System
    float luminance(vec3 color) {
        return dot(color, AP1_2_XYZ_MAT[1]);
    }
#else
    // REC. 709 -> https://en.wikipedia.org/wiki/Luma_(video)
    float luminance(vec3 color) {
        return dot(color, SRGB_2_XYZ_MAT[1]);
    }
#endif

// https://www.titanwolf.org/Network/q/bb468365-7407-4d26-8441-730aaf8582b5/x
vec3 linearToSrgb(vec3 linear) {
    vec3 higher = (pow(abs(linear), vec3(0.41666666)) * 1.055) - 0.055;
    vec3 lower  = linear * 12.92;
    return mix(higher, lower, step(linear, vec3(0.0031308)));
}

vec3 srgbToLinear(vec3 sRGB) {
    vec3 higher = pow((sRGB + 0.055) * 0.94786729, vec3(2.4));
    vec3 lower  = sRGB * 0.07739938;
    return mix(higher, lower, step(sRGB, vec3(0.04045)));
}

vec3 linearToAP1(vec3 color) {
    return color * SRGB_2_AP1;
}

vec3 ap1ToLinear(vec3 color) {
    return (AP1_2_XYZ_MAT * color) * XYZ_2_SRGB_MAT;
}

vec3 srgbToAP1Albedo(vec3 color) {
    return srgbToLinear(color) * SRGB_2_AP1_ALBEDO;
}

//////////////////////////////////////////////////////////
/*---------------------- TONEMAPS ----------------------*/
//////////////////////////////////////////////////////////

void whitePreservingReinhard(inout vec3 color, float white) {
	float luminance      = luminance(color);
	float toneMappedLuma = luminance * (1.0 + luminance / (white * white)) / (1.0 + luminance);
	color               *= toneMappedLuma / luminance;
}

void reinhardJodie(inout vec3 color) {
    float luminance = luminance(color);
    vec3 tv         = color / (1.0 + color);
    color           = mix(color / (1.0 + luminance), tv, tv);
}

void lottes(inout vec3 color) {
    const vec3 a      = vec3(1.6);
    const vec3 d      = vec3(0.977);
    const vec3 hdrMax = vec3(8.0);
    const vec3 midIn  = vec3(0.18);
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
void burgess(inout vec3 color) {
    vec3 maxColor = color * min(vec3(1.0), 1.0 - exp(-1.0 / 0.004 * color)) * 0.8;
            color = (maxColor * (6.2 * maxColor + 0.5)) / (maxColor * (6.2 * maxColor + 1.7) + 0.06);
}

//////////////////////////////////////////////////////////
/*------------------ COLOR CORRECTION ------------------*/
//////////////////////////////////////////////////////////

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
         rgb /= max(rgb.r, max(rgb.g, rgb.b)); // Keeping the values below 1.0
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
    #if TONEMAP == 0
        mat3 toXyz   = AP1_2_XYZ_MAT;
        mat3 fromXyz = XYZ_2_AP1_MAT;
    #else
        mat3 toXyz   = SRGB_2_XYZ_MAT;
        mat3 fromXyz = XYZ_2_SRGB_MAT;
    #endif

    vec3 source           = blackbody(WHITE_BALANCE) * toXyz;
    vec3 destination      = blackbody(WHITE_POINT)   * toXyz;
    mat3 chromaAdaptation = toXyz * chromaticAdaptationMatrix(source, destination) * fromXyz;

    color *= chromaAdaptation;
}

void vibrance(inout vec3 color, float intensity) {
    float mn       = minOf(color);
    float mx       = maxOf(color);
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
    vec3 lerpV = pow(color, vec3(gamma));
    color = gain * lerpV + lift * (1.0 - lerpV);
}
