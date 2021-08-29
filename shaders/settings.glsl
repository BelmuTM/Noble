/***********************************************/
/*       Copyright (C) Noble RT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#define ABOUT 0 // [0 1]

/*------------------ MATH ------------------*/
#define EPS 0.001

#define HALF_PI 1.570796
#define PI 3.141592653589
#define PI2 6.28318530718

#define INV_SQRT_OF_2PI 0.398942280
#define INV_PI 0.31831

#define GOLDEN_RATIO 1.618033988
#define GOLDEN_ANGLE 2.399963229

/*------------------ OPTIFINE CONSTANTS ------------------*/
const float sunPathRotation = -40.0; // [-85.0 -80.0 -75.0 -70.0 -65.0 -60.0 -55.0 -50.0 -45.0 -40.0 -35.0 -30.0 -25.0 -20.0 -15.0 -10.0 -5.0 0.0 5.0 10.0 15.0 20.0 25.0 30.0 35.0 40.0 45.0 50.0 55.0 60.0 65.0 70.0 75.0 80.0 85.0]
const int noiseTextureResolution = 1028;

const int shadowMapResolution = 2048; //[512 1024 2048 3072 4096 6144]
const float shadowDistance = 200.0; // [10.0 20.0 30.0 40.0 50.0 60.0 70.0 80.0 90.0 100.0 110.0 120.0 130.0 140.0 150.0 160.0 170.0 180.0 190.0 200.0 210.0 220.0 230.0 240.0 250.0 260.0 270.0 280.0 290.0 300.0]
const float shadowDistanceRenderMul = 1.0;

/*------------------ WATER ------------------*/
#define WATER_ALPHA 0.1
#define WATER_ABSORPTION_COEFFICIENTS vec3(1.0, 0.2, 0.13)

#define WATER_FOAM 1 // [0 1]
#define FOAM_BRIGHTNESS 1.00 // [0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00 1.10 1.20 1.30 1.40 1.50 1.60 1.70 1.80 1.90 2.00]
#define FOAM_FALLOFF_DISTANCE 0.75
#define FOAM_EDGE_FALLOFF 0.3
#define FOAM_FALLOFF_BIAS 0.1

/*------------------ LIGHTING ------------------*/
#define AMBIENT vec3(0.08)
#define PTGI_AMBIENT vec3(0.002)

#define TORCHLIGHT_MULTIPLIER 2.0
#define TORCH_COLOR vec3(1.5, 0.85, 0.88)
#define SUN_INTENSITY 4.0

#define SPECULAR 1 // [0 1]
#define WHITE_WORLD 0 // [0 1]

/*------------------ AMBIENT OCCLUSION ------------------*/
#define AO 1 // [0 1]
#define AO_TYPE 0 // [0 1]
#define AO_FILTER 1 // [0 1]
#define AO_BIAS 0.8

#if AO == 1
     const float ambientOcclusionLevel = 0.0;
#else
     const float ambientOcclusionLevel = 1.0;
#endif

#define SSAO_SAMPLES 8 // [4 8 16 32]
#define SSAO_RADIUS 0.6

#define RTAO_SAMPLES 4
#define RTAO_STEPS 24

/*------------------ SHADOWS ------------------*/
#define SHADOWS 1 // [0 1]
#define SOFT_SHADOWS 0 // [0 1]
#define SHADOW_SAMPLES 3 // [1 2 3 4 5 6]
#define DISTORT_FACTOR 0.5 // Lower number means better shadows near you and worse shadows farther away.
#define SHADOW_BIAS 0.1 // Increase this if you get shadow acne. Decrease this if you get peter panning.

// Soft Shadows
#define PCSS_SAMPLES 20
#define LIGHT_SIZE 100.0
#define BLOCKER_SEARCH_RADIUS 65.0
#define BLOCKER_SEARCH_SAMPLES 20

/*------------------ RAY TRACING ------------------*/
#define RAY_STEP_LENGTH 1.3 // [0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]

#define BINARY_REFINEMENT 1 // [0 1]
#define BINARY_COUNT 8 // [2 4 8 16 32]
#define BINARY_DECREASE 0.5

/*------------------ GLOBAL ILLUMINATION ------------------*/
#define GI 1 // [0 1]
#define GI_STEPS 24
#define GI_BOUNCES 3 // [1 2 3 4 5 6]
#define GI_TEMPORAL_ACCUMULATION 1 // [0 1]
#define GI_RESOLUTION 0.85 // [0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]

// Spatial Filtering
#define GI_FILTER 1 // [0 1]
#define GI_FILTER_RES 0.7
#define GI_FILTER_SIZE 35.0
#define GI_FILTER_QUALITY 7.0
#define EDGE_STOP_THRESHOLD 0.8 // Lower number means more accuracy with the spatial filter.

/*------------------ REFLECTIONS | REFRACTIONS ------------------*/
#define SSR 1 // [0 1]
#define SSR_TYPE 1 // [0 1]
#define REFRACTION 0 // [0 1]

const float hardCodedRoughness = 0.0; // 0.0 = OFF
#define ATTENUATION_FACTOR 0.375

#define PREFILTER_SAMPLES 3 // [2 3 4 8 12 16 20]
#define ROUGH_REFLECT_STEPS 16
#define ROUGH_REFLECT_RES 0.65

#define SIMPLE_REFLECT_STEPS 64
#define REFRACT_STEPS 64

/*------------------ ATMOSPHERICS ------------------*/
#define VL 0 // [0 1]
#define VL_SAMPLES 8 // [4 8 12 16 24 32 48]
#define VL_DENSITY 0.1
#define VL_FILTER 1 // [0 1]

#define RAIN_FOG 1 // [0 1]

/*------------------ POST PROCESSING ------------------*/
#define TAA 1 // [0 1]
#define TAA_STRENGTH 0.500 // [0.025 0.050 0.075 0.100 0.125 0.150 0.175 0.200 0.225 0.250 0.275 0.300 0.325 0.350 0.375 0.400 0.425 0.450 0.475 0.500 0.525 0.550 0.575 0.600 0.625 0.650 0.675 0.700 0.725 0.750 0.775 0.800 0.825 0.850 0.875 0.900 0.925 0.950 0.975]

#define DOF 1 // [0 1]
#define DOF_STRENGTH 1.00 // [0.25 0.50 0.75 1.00 1.25 1.50 1.75 2.00 2.25 2.50 2.75 3.00]

#define BLOOM 1 // [0 1]
#define BLOOM_STRENGTH 1.00 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define BLOOM_LUMA_THRESHOLD 0.4

#define VIGNETTE 1 // [0 1]
#define VIGNETTE_FALLOFF 0.2
#define VIGNETTE_STRENGTH 0.65 // [0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]

#define CHROMATIC_ABERRATION 0 // [0 1]
#define ABERRATION_STRENGTH 30.0 // [5.0 10.0 15.0 20.0 25.0 30.0 35.0 40.0 45.0 50.0 55.0 60.0 65.0 70.0 75.0 80.0]

#define OUTLINE 0 // [0 1]
#define OUTLINE_DARKNESS 0.80 // [0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]
#define OUTLINE_THICKNESS 1.00 // [0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]

/*------------------ CAMERA ------------------*/
#define LENS_LENGTH 15.0
#define APERTURE 4.0
#define ISO 100.0
#define SHUTTER_SPEED 50.0
const float K = 12.5; // Light meter calibration
const float S = 100.0; // Sensor sensitivity

#define AUTO_EXPOSURE 1 // [0 1]
#define MIN_EXPOSURE 0.5
#define MAX_EXPOSURE 5.0

/*------------------ COLOR CORRECTION ------------------*/
#define TONEMAPPING 0 // [-1 0 1 2 3]

#define VIBRANCE 1.00 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define SATURATION 1.00 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define CONTRAST 1.00 // [0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50]
#define BRIGHTNESS 0.00 // [-0.25 -0.20 -0.15 -0.10 -0.05 0.00 0.05 0.10 0.15 0.20 0.25]
