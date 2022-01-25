/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
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
/*------------------ COLOR CONVERSION ------------------*/
//////////////////////////////////////////////////////////

// REC. 709 -> https://en.wikipedia.org/wiki/Luma_(video)
float luminance(vec3 color) {
    return dot(color, REC_709);
}

// https://www.titanwolf.org/Network/q/bb468365-7407-4d26-8441-730aaf8582b5/x
vec4 linearToRGB(vec4 linear) {;
    vec4 higher = (pow(abs(linear), vec4(1.0 / 2.4)) * 1.055) - 0.055;
    vec4 lower  = linear * 12.92;
    return mix(higher, lower, step(linear, vec4(0.0031308)));
}

vec4 RGBtoLinear(vec4 sRGB) {
    vec4 higher = pow((sRGB + 0.055) / 1.055, vec4(2.4));
    vec4 lower  = sRGB / 12.92;
    return mix(higher, lower, step(sRGB, vec4(0.04045)));
}

vec3 linearToRGB(vec3 linear) {;
    vec3 higher = (pow(abs(linear), vec3(1.0 / 2.4)) * 1.055) - 0.055;
    vec3 lower  = linear * 12.92;
    return mix(higher, lower, step(linear, vec3(0.0031308)));
}

vec3 RGBtoLinear(vec3 sRGB) {
    vec3 higher = pow((sRGB + 0.055) / 1.055, vec3(2.4));
    vec3 lower  = sRGB / 12.92;
    return mix(higher, lower, step(sRGB, vec3(0.04045)));
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

vec3 linearToXYZ(vec3 linear) { return linearToRGB(linear) * RGBtoXYZMatrix; }
vec3 XYZToLinear(vec3 xyz)    { return RGBtoLinear(xyz * XYZtoRGBMatrix);    }

// https://www.shadertoy.com/view/ltjBWG
const mat3 RGBToYCoCgMatrix = mat3(0.25, 0.5,-0.25, 0.5, 0.0, 0.5, 0.25, -0.5,-0.25);
const mat3 YCoCgToRGBMatrix = mat3(1.0,  1.0,  1.0, 1.0, 0.0,-1.0, -1.0,  1.0, -1.0);

vec3 linearToYCoCg(vec3 linear) { return linearToRGB(linear).rgb * RGBToYCoCgMatrix; }
vec3 YCoCgToLinear(vec3 YCoCg)  { return RGBtoLinear(YCoCg * YCoCgToRGBMatrix).rgb;  }

// Temperature to RGB function from https://www.shadertoy.com/view/4sc3D7
vec3 colorTemperatureToRGB(const in float temperature){
  // Values from http://blenderartists.org/forum/showthread.php?270332-OSL-Goodness&p=2268693&viewfull=1#post2268693   
  mat3 m = (temperature <= 6500.0) ? mat3(vec3(0.0, -2902.1955373783176, -8257.7997278925690),
	                                      vec3(0.0, 1669.5803561666639, 2575.2827530017594),
	                                      vec3(1.0, 1.3302673723350029, 1.8993753891711275)) : 
	 								 mat3(vec3(1745.0425298314172, 1216.6168361476490, -8257.7997278925690),
   	                                      vec3(-2666.3474220535695, -2173.1012343082230, 2575.2827530017594),
	                                      vec3(0.55995389139931482, 0.70381203140554553, 1.8993753891711275)); 
  return mix(clamp(vec3(m[0] / (vec3(clamp(temperature, 1000.0, 40000.0)) + m[1]) + m[2]), vec3(0.0), vec3(1.0)), vec3(1.0), smoothstep(1000.0, 0.0, temperature));
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
         rgb = rgb / max(rgb.x, max(rgb.y, rgb.z));
    return rgb;
}

//////////////////////////////////////////////////////////
/*------------------ COLOR CORRECTION ------------------*/
//////////////////////////////////////////////////////////

/*
    Sources for White Balance:
    https://en.wikipedia.org/wiki/LMS_color_space
    https://en.wikipedia.org/wiki/Von_Kries_coefficient_law
    https://github.com/zombye/spectrum
*/

mat3 chromaticAdaptationMatrix(vec3 source, vec3 destination) {
    const mat3 XYZToLMS = mat3(
		0.7328, 0.4296,-0.1624,
	   -0.7036, 1.6975, 0.0061,
		0.0030, 0.0136, 0.9834
	); // CIECAM02 (CAT02)

	vec3 sourceLMS      = source * XYZToLMS;
	vec3 destinationLMS = destination * XYZToLMS;
	vec3 tmp            = destinationLMS / sourceLMS;

	mat3 vonKries = mat3(
		tmp.x, 0.0, 0.0,
		0.0, tmp.y, 0.0,
		0.0, 0.0, tmp.z
	);

	return (XYZToLMS * vonKries) * inverse(XYZToLMS);
}

void whiteBalance(inout vec3 color) {
    vec3 source              = blackbody(WHITE_BALANCE) * RGBtoXYZMatrix;
    vec3 destination         = blackbody(6500.0) * RGBtoXYZMatrix;
    mat3 chromaticAdaptation = RGBtoXYZMatrix * chromaticAdaptationMatrix(source, destination) * XYZtoRGBMatrix;
    color                   *= chromaticAdaptation;
}

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
void burgess(inout vec3 color) {
    vec3 maxColor = color * min(vec3(1.0), 1.0 - exp(-1.0 / 0.04 * color)) * 1.1;
    color         = (maxColor * (6.2 * maxColor + 0.5)) / (maxColor * (6.2 * maxColor + 1.7) + 0.04);
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
    vec3 a = v * (v + 0.0245786) - 0.000090537;
    vec3 b = v * (0.983729 * v + 0.4329510) + 0.238081;
    return a / b;
}

void ACESFitted(inout vec3 color) {
    color = clamp01(RRTAndODTFit(color * ACESInputMat) * ACESOutputMat);
}

void ACESApprox(inout vec3 color) {
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    color         = clamp01((color * (a * color + b)) / (color * (c * color + d) + e));
}

void vibrance(inout vec3 color, float intensity) {
    float mn       = min(min(color.r, color.g), color.b);
    float mx       = max(max(color.r, color.g), color.b);
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
