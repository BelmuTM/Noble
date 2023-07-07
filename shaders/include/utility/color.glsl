/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

/*
    [Credits]:
        Jessie - providing blackbody radiation function (https://github.com/Jessie-LC/open-source-utility-code/blob/main/advanced/blackbody.glsl)

    [References]:
        Uchimura, H. (2017). HDR Theory and practice. https://www.slideshare.net/nikuque/hdr-theory-and-practicce-jp
        Uchimura, H. (2017). GT Tonemap. https://www.desmos.com/calculator/gslcdxvipg?lang=fr
        Hable, J. (2017). Minimal Color Grading Tools. http://filmicworlds.com/blog/minimal-color-grading-tools/
        Taylor, M. (2019). Tone Mapping. https://64.github.io/tonemapping/
        Wikipedia. (2022). YCoCg. https://en.wikipedia.org/wiki/YCoCg
        Wikipedia. (2023). Von Kries coefficient law. https://en.wikipedia.org/wiki/Von_Kries_coefficient_law
        Wikipedia. (2023). LMS color space. https://en.wikipedia.org/wiki/LMS_color_space
        Wikipedia. (2023). Academy Color Encoding System. https://en.wikipedia.org/wiki/Academy_Color_Encoding_System
        Wikipedia. (2023). Luma (video). https://en.wikipedia.org/wiki/Luma_(video)
        Wikipedia. (2023). sRGB. https://en.wikipedia.org/wiki/SRGB
*/

//////////////////////////////////////////////////////////
/*------------- COLOR CONVERSION MATRICES --------------*/
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

const mat3 SRGB_2_YCoCg_MAT = mat3(0.25, 0.5, -0.25, 0.5, 0.0,  0.5,  0.25, -0.5, -0.25);
const mat3 YCoCg_2_SRGB_MAT = mat3(1.00, 1.0,  1.00, 1.0, 0.0, -1.0, -1.00,  1.0, -1.00);

//////////////////////////////////////////////////////////
/*----------------- COLOR CONVERSIONS ------------------*/
//////////////////////////////////////////////////////////

float luminance(vec3 color) {
    #if TONEMAP == ACES
        vec3 luminanceCoefficients = AP1_2_XYZ_MAT[1];
    #else
        vec3 luminanceCoefficients = SRGB_2_XYZ_MAT[1];
    #endif

    return dot(color, luminanceCoefficients);
}

const float SRGB_ALPHA = 0.055;

vec3 linearToSrgb(vec3 linear) {
    vec3 higher = (pow(abs(linear), vec3(0.41666666)) * (1.0 + SRGB_ALPHA)) - SRGB_ALPHA;
    vec3 lower  = linear * 12.92;
    return mix(higher, lower, step(linear, vec3(0.0031308)));
}

vec3 srgbToLinear(vec3 srgb) {
    vec3 higher = pow((srgb + SRGB_ALPHA) * 0.94786729, vec3(2.4));
    vec3 lower  = srgb * 0.07739938;
    return mix(higher, lower, step(srgb, vec3(0.04045)));
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

vec3 fromXyz(vec3 color) {
    #if TONEMAP == ACES
        return color * XYZ_2_AP1_MAT;
    #else
        return color * XYZ_2_SRGB_MAT;
    #endif
}

vec3 toXyz(vec3 color) {
    #if TONEMAP == ACES
        return color * AP1_2_XYZ_MAT;
    #else
        return color * SRGB_2_XYZ_MAT;
    #endif
}

mat3 fromXyz(mat3 mat) {
    #if TONEMAP == ACES
        return mat * XYZ_2_AP1_MAT;
    #else
        return mat * XYZ_2_SRGB_MAT;
    #endif
}

mat3 toXyz(mat3 mat) {
    #if TONEMAP == ACES
        return mat * AP1_2_XYZ_MAT;
    #else
        return mat * SRGB_2_XYZ_MAT;
    #endif
}

vec3 plancks(float temperature, vec3 lambda) {
    const float h = 6.62607015e-16; // Planck's constant
    const float c = 2.99792458e17;  // Speed of light in a vacuum
    const float k = 1.38064852e-5;  // Boltzmann's constant

    float numerator   = 2.0 * h * pow2(c);
    vec3  denominator = (exp(h * c / (lambda * k * temperature)) - vec3(1.0)) * pow5(lambda);
    return (numerator / denominator) * pow2(1e9);
}

vec3 blackbody(float temperature) {
    vec3 rgb  = plancks(temperature, vec3(660.0, 550.0, 440.0));
         rgb /= maxOf(rgb); // Keeping the values below 1.0
    return rgb;
}

#if PURKINJE == 1
    void scotopicVisionApproximation(inout vec3 color) {
        const float bias    = 0.5;
        const float rcpBias = 1.0 / bias;
        const vec2 xy_b     = vec2(0.25);

        vec3 xyz = toXyz(color * rcpBias);

        float s;
        if(log10(xyz.y) < -2.0) {
            s = 0.0;
        } else if(log10(xyz.y) < 0.6) {
            s = 3.0 * pow2((log10(xyz.y) + 2.0) / 2.6) - 2.0 * pow3((log10(xyz.y) + 2.0) / 2.6);
        } else {
            s = 1.0;
        }

        float W = xyz.x + xyz.y + xyz.z;
        float x = xyz.x / W;
        float y = xyz.y / W;
              x = (1.0 - s) * xy_b.x + s * x;
              y = (1.0 - s) * xy_b.y + s * y;

        color.g = 0.4468 * (1.0 - s) * xyz.y + s * xyz.y;
        color.r = (x * color.g) / y;
        color.b = (color.r / x) - color.r - color.g;

        color = fromXyz(color) * bias;
    }
#endif
