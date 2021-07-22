/***********************************************/
/*       Copyright (C) Noble RT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/*------------------ MATH ------------------*/
#define EPS 0.001

#define PI 3.141592653589
#define PI2 6.28318530718

#define INV_SQRT_OF_2PI 0.3989422804014326
#define INV_PI 0.31831

#define GOLDEN_RATIO 1.61803398874989484820459
#define GOLDEN_ANGLE 2.39996322973

/*------------------ OPTIFINE CONSTANTS ------------------*/
const float sunPathRotation = -40.0; // [-85.0 -80.0 -75.0 -70.0 -65.0 -60.0 -55.0 -50.0 -45.0 -40.0 -35.0 -30.0 -25.0 -20.0 -15.0 -10.0 -5.0 0.0 5.0 10.0 15.0 20.0 25.0 30.0 35.0 40.0 45.0 50.0 55.0 60.0 65.0 70.0 75.0 80.0 85.0]
const int noiseTextureResolution = 1028;
const float ambientOcclusionLevel = 0.0;

const int shadowMapResolution = 3072; //[512 1024 2048 3072 4096 6144]
const float shadowDistance = 200.0; // [10.0 20.0 30.0 40.0 50.0 60.0 70.0 80.0 90.0 100.0 110.0 120.0 130.0 140.0 150.0 160.0 170.0 180.0 190.0 200.0 210.0 220.0 230.0 240.0 250.0 260.0 270.0 280.0 290.0 300.0]
const float shadowDistanceRenderMul = 1.0;

/*------------------ NOISE ------------------*/
#define FBM_OCTAVES 6 // FBM
#define RADIUS 6 // Denoiser

/*------------------ LIGHTING ------------------*/
#define AMBIENT vec3(0.01)

#define TORCHLIGHT_MULTIPLIER 2.0
#define TORCH_COLOR vec3(1.5, 0.85, 0.88)

#define SSAO 0 // [0 1]
#define SSAO_SAMPLES 16 // [4 8 16 32 64 128]
#define SSAO_RADIUS 1.0
#define SSAO_BIAS 0.5

#define SPECULAR 1 // [0 1]
#define WHITE_WORLD 0 // [0 1]

/*------------------ WATER ------------------*/
#define WATER_WAVE_SPEED 0.15
#define WATER_WAVE_AMPLITUDE 0.02
#define WATER_WAVE_LENGTH 0.9
#define WATER_WAVE_AMOUNT 5
#define WATER_ABSORPTION_COEFFICIENTS vec3(1.0, 0.2, 0.13)

#define WATER_FOAM 1 // [0 1]
#define FOAM_BRIGHTNESS 0.5 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
#define FOAM_FALLOFF_DISTANCE 0.75
#define FOAM_EDGE_FALLOFF 0.3
#define FOAM_FALLOFF_BIAS 0.1

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

#define BINARY_REFINEMENT 1 // [0 1]
#define BINARY_COUNT 8 // [4 8 16 32 48]
#define BINARY_DECREASE 0.5

#define GI 1 // [0 1]
#define GI_BOUNCES 2 // [1 2 3 4 5 6]
#define GI_TEMPORAL_ACCUMULATION 1 // [0 1]
#define GI_RESOLUTION 0.55 // [0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]
// Spatial Filtering
#define GI_FILTER 0 // [0 1]
#define GI_FILTER_RES 0.5
#define GI_FILTER_SIZE 15.0
#define GI_FILTER_QUALITY 7.0
#define EDGE_STOP_THRESHOLD 0.7 // Lower number means more accuracy with the spatial filter.

#define SSR 1 // [0 1]
#define SSR_TYPE 1 // [0 1]
#define WATER_REFRACTION 0 // [0 1]

/*------------------ REFLECTIONS ------------------*/
#define SIMPLE_REFLECT_STEPS 64
#define ROUGH_REFLECT_STEPS 12
#define SIMPLE_REFRACT_STEPS 20

#define ATTENUATION_FACTOR 0.375
#define PREFILTER_SAMPLES 12 // [4 8 12 16 20 24]

/*------------------ VOLUMETRIC LIGHTING ------------------*/
#define VL 0 // [0 1]
#define VL_SAMPLES 8 // [4 8 12 16 24 32 48]
#define VL_DENSITY 0.4
#define VL_BRIGHTNESS 1.00 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define VL_BLUR 1 // [0 1]

/*------------------ FINAL ------------------*/
#define ABOUT 69.420

// Depth of Field
#define DOF 1 // [0 1]
#define DOF_DISTANCE 120 // [0 10 20 30 40 50 60 70 80 90 100 110 120 130 140 150 160 170 180 190 200]
#define MIN_DISTANCE 5
#define FOCAL 0.3
#define APERTURE 0.3
#define SIZEMULT 1.0

#define BLOOM 1 // [0 1]
#define BLOOM_INTENSITY 1.00 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define BLOOM_RESOLUTION_MULTIPLIER 1.0
#define BLOOM_QUALITY 15.0
#define BLOOM_SIZE 5.0
#define BLOOM_DIRECTIONS 20.0

#define OUTLINE 0 // [0 1]
#define OUTLINE_DARKNESS 0.80 // [0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]
#define OUTLINE_THICKNESS 1.00 // [0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]

#define VIGNETTE 1 // [0 1]
#define VIGNETTE_FALLOFF 0.2
#define VIGNETTE_AMOUNT 0.6

// Color Correction
#define TONEMAPPING 5 // [-1 0 1 2 3 4 5]
#define EXPOSURE 1.50 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00 2.05 2.10 2.15 2.20 2.25 2.30 2.35 2.40 2.45 2.50 2.55 2.60 2.65 2.70 2.75 2.80 2.85 2.90 2.95 3.00]
#define VIBRANCE 1.00 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define SATURATION 1.00 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define CONTRAST 1.00 // [0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50]
#define BRIGHTNESS 0.00 // [-0.25 -0.20 -0.15 -0.10 -0.05 0.00 0.05 0.10 0.15 0.20 0.25]
