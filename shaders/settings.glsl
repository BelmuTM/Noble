/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#define OVERWORLD 0
#define NETHER   -1

#define STAGE_VERTEX   0
#define STAGE_FRAGMENT 1

#define ABOUT 0 // [0 1]

/*------------------ MATH ------------------*/
#define REC_709 vec3(0.2126, 0.7152, 0.0722)
#define EPS 1e-4

#define HALF_PI      1.570796
#define PI           3.14159265
#define TAU          6.28318530
#define INV_PI       0.31831

#define GOLDEN_RATIO 1.618033988
#define GOLDEN_ANGLE 2.399963229

/*------------------ OPTIFINE CONSTANTS ------------------*/
const float sunPathRotation      = -40.0; // [-85.0 -80.0 -75.0 -70.0 -65.0 -60.0 -55.0 -50.0 -45.0 -40.0 -35.0 -30.0 -25.0 -20.0 -15.0 -10.0 -5.0 0.0 5.0 10.0 15.0 20.0 25.0 30.0 35.0 40.0 45.0 50.0 55.0 60.0 65.0 70.0 75.0 80.0 85.0]
const int noiseTextureResolution =   256;

const int shadowMapResolution =  3072; // [512 1024 2048 3072 4096 6144]
const float shadowDistance    = 200.0; // [10.0 20.0 30.0 40.0 50.0 60.0 70.0 80.0 90.0 100.0 110.0 120.0 130.0 140.0 150.0 160.0 170.0 180.0 190.0 200.0 210.0 220.0 230.0 240.0 250.0 260.0 270.0 280.0 290.0 300.0]

/*------------------ LIGHTING ------------------*/
const float rainAmbientDarkness = 0.3;

#define TORCHLIGHT_MULTIPLIER 5.0
#define TORCHLIGHT_EXPONENT   3.0

#define TORCH_COLOR_R 0.79 // [0.00 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.10 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.20 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.30 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.40 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.50 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.60 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.70 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.80 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.90 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.00]
#define TORCH_COLOR_G 0.50 // [0.00 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.10 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.20 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.30 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.40 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.50 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.60 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.70 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.80 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.90 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.00]
#define TORCH_COLOR_B 0.30 // [0.00 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.10 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.20 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.30 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.40 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.50 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.60 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.70 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.80 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.90 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.00]
#define TORCH_COLOR vec3(TORCH_COLOR_R, TORCH_COLOR_G, TORCH_COLOR_B)

#define SUN_INTENSITY    15.0
#define SUN_COLOR        vec3(1.0, 0.97, 0.94)
#define SUN_ILLUMINANCE  (SUN_INTENSITY * SUN_COLOR)
#define MOON_ILLUMINANCE vec3(0.02)

#define SPECULAR    1 // [0 1]
#define WHITE_WORLD 0 // [0 1]

/*------------------ AMBIENT OCCLUSION ------------------*/
#define AO        1 // [0 1]
#define AO_TYPE   0 // [0 1]
#define AO_FILTER 1 // [0 1]

#define SSAO_SAMPLES    8 // [4 8 12 16 20]
#define SSAO_RADIUS   0.5
#define SSAO_STRENGTH 1.5

#define RTAO_SAMPLES 3 // [3 16]
#define RTAO_STEPS  16

/*------------------ SHADOWS ------------------*/
#define SHADOWS         1 // [0 1]
#define SOFT_SHADOWS    1 // [0 1]
#define CONTACT_SHADOWS 0

#define SHADOW_SAMPLES   3 // [1 2 3 4 5 6]
#define DISTORT_FACTOR 0.9
#define SHADOW_BIAS    0.8

// Soft Shadows
#define PCSS_SAMPLES            24 // [24 64]
#define LIGHT_SIZE           100.0
#define BLOCKER_SEARCH_RADIUS 12.0
#define BLOCKER_SEARCH_SAMPLES  20 // [20 64]

/*------------------ RAY TRACING ------------------*/
#define BINARY_REFINEMENT 1 // [0 1]
#define BINARY_COUNT      4 // [4 6 12]
#define BINARY_DECREASE 0.5

#define RAY_STEP_LENGTH 1.7

/*------------------ GLOBAL ILLUMINATION ------------------*/
#define GI        0 // [0 1]
#define GI_FILTER 0 // [0 1]

#define GI_SAMPLES 1 // [1 2 3]
#define GI_BOUNCES 4 // [1 2 3 4 5 6 7 8]
#define GI_STEPS  40 // [40 128]
#define GI_RESOLUTION 1.00 // [0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]

#define GI_TEMPORAL_ACCUMULATION     1 // [0 1]
#define ACCUMULATION_VELOCITY_WEIGHT 0 //[0 1]

/*------------------ REFLECTIONS | REFRACTIONS ------------------*/
#define SSR        1 // [0 1]
#define SSR_TYPE   1 // [0 1]
#define REFRACTION 1 // [0 1]

const float hardCodedRoughness = 0.0; // 0.0 = OFF
#define ATTENUATION_FACTOR 0.325

#define SKY_FALLBACK     1
#define SSR_REPROJECTION 1 // [0 1]

#define PREFILTER_SAMPLES    3 // [3 12]
#define ROUGH_REFLECT_STEPS 20 // [20 64]
#define ROUGH_REFLECT_RES 0.80 // [0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]

#define SIMPLE_REFLECT_STEPS 64
#define REFRACT_STEPS        56

/*------------------ ATMOSPHERICS ------------------*/
#define ATMOSPHERE_RESOLUTION 0.5
#define SCATTER_STEPS          16 // [8 12 16 20 24 28 32 36]
#define TRANSMITTANCE_STEPS     8 // [8 12 16 20 24 28 32 36]

#define VL        0 // [0 1]
#define VL_FILTER 1 // [0 1]

#define RAIN_FOG 1 // [0 1]

/*------------------ WATER ------------------*/
#define ANIMATED_WATER 1 // [0 1]

// PBR
#define WATER_ABSORPTION_COEFFICIENTS vec3(1.0, 0.2, 0.13)

#define WAVE_STEEPNESS 2.00 // [0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define WAVE_AMPLITUDE 0.04 // [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.10 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.20]
#define WAVE_LENGTH    2.00 // [0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define WAVE_SPEED     0.20 // [0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]

// POST-EFFECTS
#define WATER_FOAM               1 // [0 1]
#define FOAM_BRIGHTNESS       0.50 // [0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00 1.10 1.20 1.30 1.40 1.50 1.60 1.70 1.80 1.90 2.00]
#define FOAM_FALLOFF_DISTANCE 0.75
#define FOAM_EDGE_FALLOFF      0.4
#define FOAM_FALLOFF_BIAS      0.1

#define UNDERWATER_DISTORTION         1 // [0 1]
#define WATER_DISTORTION_SPEED     0.65
#define WATER_DISTORTION_AMPLITUDE 0.40 // [0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]

#define WATER_CAUSTICS             1 // [0 1]
#define WATER_CAUSTICS_STRENGTH 5.00 // [1.00 1.25 1.50 1.75 2.00 2.25 2.50 2.75 3.00 3.25 3.50 3.75 4.00 4.25 4.50 4.75 5.00 5.25 5.50 5.75 6.00 6.25 6.50 6.75 7.00 7.25 7.50 7.75 8.00 8.25 8.50 8.75 9.00 9.25 9.50 9.75 10.00]
#define WATER_CAUSTICS_SPEED    10.0

/*------------------ POST PROCESSING ------------------*/
#define TAA               1 // [0 1]
#define TAA_STRENGTH  0.950 // [0.800 0.812 0.825 0.837 0.850 0.862 0.875 0.887 0.900 0.912 0.925 0.937 0.950 0.962 0.975 0.987]
#define NEIGHBORHOOD_SIZE 1 // [1 2 3]

#define TAA_VELOCITY_WEIGHT 0 // [0 1]
#define TAA_LUMA_MIN 0.15

#define PURKINJE 0 // [0 1]

#define DOF           0 // [0 1]
#define DOF_RADIUS 20.0 // [5.0 6.0 7.0 8.0 9.0 10.0 11.0 12.0 13.0 14.0 15.0 16.0 17.0 18.0 19.0 20.0 21.0 22.0 23.0 24.0 25.0 26.0 27.0 28.0 29.0 30.0 31.0 32.0 33.0 34.0 35.0 36.0 37.0 38.0 39.0 40.0]

#define BLOOM                  1 // [0 1]
#define BLOOM_STRENGTH      1.00 // [0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define BLOOM_LUMA_THRESHOLD 0.5

#define VIGNETTE             0 // [0 1]
#define VIGNETTE_STRENGTH 0.25 // [0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50]

#define CHROMATIC_ABERRATION   0 // [0 1]
#define ABERRATION_STRENGTH 1.50 // [0.25 0.50 0.75 1.00 1.25 1.50 1.75 2.00 2.25 2.50 2.75 3.00]

/*------------------ CAMERA ------------------*/
#define FOCAL        7.0 // [1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0 11.0 12.0 13.0 14.0 15.0 16.0 17.0 18.0 19.0 20.0]
#define APERTURE     4.0 // [1.0 1.2 1.4 2.0 2.8 4.0 5.6 8.0 11.0 16.0 22.0 32.0]
#define ISO          200 // [50 100 200 400 800 1600 3200 6400 12800 25600 51200]
#define SHUTTER_SPEED 60 // [4 5 6 8 10 15 20 30 40 50 60 80 100 125 160 200 250 320 400 500 640 800 1000 1250 1600 2000 2500 3200 4000]

const float K =  17.0; // Light meter calibration
const float S = 100.0; // Sensor sensitivity

#define EXPOSURE 1 // [0 1]

/*------------------ COLOR CORRECTION ------------------*/
#define TONEMAP 3 // [-1 0 1 2 3]
#define LUT     0 // [0 1]

#define VIBRANCE   1.00 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define SATURATION 1.00 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define CONTRAST   1.00 // [0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50]
#define BRIGHTNESS 0.00 // [-0.25 -0.20 -0.15 -0.10 -0.05 0.00 0.05 0.10 0.15 0.20 0.25]

/*------------------ OTHER ------------------*/
#if AO == 1 || GI == 1
     const float ambientOcclusionLevel = 0.0;
#else
     const float ambientOcclusionLevel = 1.0;
#endif
