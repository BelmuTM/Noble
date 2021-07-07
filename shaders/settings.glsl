/***********************************************/
/*       Copyright (C) Noble SSRT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/*------------------ MATH ------------------*/
#define EPS 0.01

#define PI 3.141592653589
#define PI2 6.28318530718

#define INV_SQRT_OF_2PI 0.3989422804014326
#define INV_PI 0.31831

/*------------------ OPTIFINE CONSTANTS ------------------*/
const float sunPathRotation = -40.0; // [80.0 75.0 70.0 65.0 60.0 55.0 50.0 45.0 40.0 35.0 30.0 25.0 20.0 15.0 10.0 5.0 0.0 -5.0 -10.0 -15.0 -20.0 -25.0 -30.0 -35.0 -40.0 -45.0 -50.0 -55.0 -60.0 -65.0 -70.0 -75.0 -80.0]
const int noiseTextureResolution = 1028;
const float ambientOcclusionLevel = 0.0;

const int shadowMapResolution = 3072; //[512 1024 2048 3072 4096 6144]
const float shadowDistanceRenderMul = 1.0;
const float shadowDistance = 120.0; // [10.0 20.0 30.0 40.0 50.0 60.0 70.0 80.0 90.0 100.0 110.0 120.0 130.0 140.0 150.0 160.0 170.0 180.0 190.0 200.0]
const bool shadowHardwareFiltering = true;
const bool shadowHardwareFiltering0 = true;
const bool shadowHardwareFiltering1 = true;

/*------------------ NOISE ------------------*/
#define FBM_OCTAVES 6 // FBM
#define RADIUS 6 // Denoiser

/*------------------ LIGHTING ------------------*/
#define WHITE_WORLD 0 // [0 1]
#define AMBIENT vec3(0.0) // If PTGI is ON

#define TORCHLIGHT_MULTIPLIER 2.0
#define TORCH_COLOR vec3(1.5, 0.85, 0.88)

#define SPECULAR 1 // [0 1]
#define DIFFUSE_LIGHTING 1 // [0 1]
#define ENERGY_CONSERVATION 0

/*------------------ WATER ------------------*/
#define WATER_WAVE_SPEED 0.15
#define WATER_WAVE_AMPLITUDE 0.02
#define WATER_WAVE_LENGTH 0.9
#define WATER_WAVE_AMOUNT 5
#define WATER_ABSORPTION_COEFFICIENTS vec3(1.0, 0.2, 0.13)

#define WATER_FOAM 1 // [0 1]
#define FOAM_BRIGHTNESS 0.3 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
#define FOAM_FALLOFF_DISTANCE 0.9
#define FOAM_EDGE_FALLOFF 0.3
#define FOAM_FALLOFF_BIAS 0.1

/*------------------ SHADOWS & SSAO ------------------*/
#define SHADOWS 1 // [0 1]
#define SHADOW_SAMPLES 3 // [1 2 3 4 5 6]
#define DISTORT_FACTOR 0.5 // Lower numbers mean better shadows near you and worse shadows farther away.
#define SHADOW_BIAS 0.1 // Increase this if you get shadow acne. Decrease this if you get peter panning.

#define SSAO 0 // [0 1]
#define SSAO_SAMPLES 16 // [4 8 16 32 64 128]
#define SSAO_RADIUS 1.0
#define SSAO_BIAS 0.5

/*------------------ RAY TRACING ------------------*/
#define BINARY_REFINEMENT 1 // [0 1]
#define BINARY_COUNT 8 // [4 8 16 32 48]
#define BINARY_DECREASE 0.5

#define PTGI 1 // [0 1]
#define PTGI_BOUNCES 2 // [1 2 3 4 5 6]
#define PTGI_TEMPORAL_ACCUMULATION 1 // [0 1]
#define PTGI_FILTER 0 // [0 1]
#define SUN_BRIGHTNESS 4.0

#define SSR 1 // [0 1]
#define SSR_TYPE 1 // [0 1]

/*------------------ REFLECTIONS ------------------*/
#define ATTENUATION_FACTOR 0.4

// Rough Reflections
#define BRDF_BIAS 0.26
#define PREFILTER_SAMPLES 2

/*------------------ VOLUMETRIC LIGHTING ------------------*/
#define VL 0 // [0 1]
#define VL_SAMPLES 8 // [4 8 12 16 24 32 48]
#define VL_DENSITY 0.2
#define VL_BRIGHTNESS 1.00 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define VL_BLUR 1 // [0 1]

/*------------------ FINAL ------------------*/
#define ABOUT 69.420

// Depth of Field
#define DOF 1 // [0 1]
#define DOF_DISTANCE 100 // [10 20 30 40 50 60 70 80 90 100 110 120 130 140 150 160 170 180 190 200]
#define MIN_DISTANCE 5
#define FOCAL 0.3
#define APERTURE 0.3
#define SIZEMULT 1.0

// Bokeh
#define BOKEH_SAMPLES 6
#define BOKEH_RADIUS 0.03

#define BLOOM 0 // [0 1]
#define BLOOM_INTENSITY 0.5 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5]

#define OUTLINE 0 // [0 1]
#define OUTLINE_DARKNESS 0.80 // [0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]

// Color Correction
#define TONEMAPPING 0 // [-1 0 1 2 3 4 5]
#define EXPOSURE 1.00 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00 2.05 2.10 2.15 2.20 2.25 2.30 2.35 2.40 2.45 2.50 2.55 2.60 2.65 2.70 2.75 2.80 2.85 2.90 2.95 3.00]
#define VIBRANCE 1.00 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define SATURATION 1.00 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define CONTRAST 1.00 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define BRIGHTNESS 0.00 // [-0.25 -0.20 -0.15 -0.10 -0.05 0.00 0.05 0.10 0.15 0.20 0.25]
