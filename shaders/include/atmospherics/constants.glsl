/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* ATMOSPHERE CONSTANTS */
const float anisotropyFactor = 0.76;
const float isotropicPhase   = 0.07957747;

const float earthRad      = 6371e3;           // meters
const float atmosLowerRad = earthRad - 3e3;   // meters
const float atmosUpperRad = earthRad + 110e3; // meters

const vec2 scaleHeights = vec2(8.40e3, 1.25e3); // meters

/* CLOUDS CONSTANTS */
const float innerCloudRad = earthRad      + CLOUDS_ALTITUDE;
const float outerCloudRad = innerCloudRad + CLOUDS_THICKNESS;

const float cloudsExtinctionCoeff   = 0.06;
const float cloudsScatteringCoeff   = 1.0;
const float cloudsTransmitThreshold = 5e-2;

const float cloudsForwardsLobe = 0.35;
const float cloudsBackardsLobe = 0.35;
const float cloudsForwardsPeak = 0.90;
const float cloudsBackScatter  = 0.20;
const float cloudsPeakWeight   = 0.15;

const int   cloudsMultiScatterSteps = 8;
const float cloudsExtinctionFalloff = 0.60;
const float cloudsScatteringFalloff = 0.55;
const float cloudsAnisotropyFalloff = 0.80;

const float cloudsShadowmapRes  = 1024.0;
const float cloudsShadowmapDist = 600.0;

// Coefficients provided by Jessie#7257 and LVutner#5199

#if TONEMAP == 0
    const vec3 rayleighCoeff = vec3(5.8e-6, 13.3e-6, 33.31e-6)                                                      * sRGB_2_AP1_ALBEDO;
    const vec3 mieCoeff      = vec3(0.00001028098)                                                                  * sRGB_2_AP1_ALBEDO;
    const vec3 ozoneCoeff    = vec3(4.51103766177301e-21, 3.2854797958699e-21, 1.96774621921165e-22) * 3.5356617e14 * sRGB_2_AP1_ALBEDO;
#else
    const vec3 rayleighCoeff = vec3(5.8e-6, 13.3e-6, 33.31e-6);
    const vec3 mieCoeff      = vec3(0.00001028098);
    const vec3 ozoneCoeff    = vec3(4.51103766177301e-21, 3.2854797958699e-21, 1.96774621921165e-22) * 3.5356617e14;
#endif

mat2x3 atmosScatteringCoeff = mat2x3(rayleighCoeff, mieCoeff);
mat3x3 atmosExtinctionCoeff = mat3x3(rayleighCoeff, mieCoeff * 1.11111, ozoneCoeff);

vec3 atmosRayPos = vec3(0.0, earthRad, 0.0) + cameraPosition;

/* CELESTIAL CONSTANTS */
const float moonRad       = 1.7374e3;
const float moonDist      = 3.8440e5;
const float moonAlbedo    = 0.136; // The moon reflects approximately 12-13% of the sun's emitted light 
const float moonRoughness = 0.40;

const float sunRad  = 6.9634e8;
const float sunDist = 1.496e11;

const float sunAngularRad  = CELESTIAL_SIZE_MULTIPLIER * sunRad  / sunDist;
const float moonAngularRad = CELESTIAL_SIZE_MULTIPLIER * moonRad / moonDist;

const vec3 sunIlluminance = vec3(1.0, 0.949, 0.937) * 126e3; // Brightness of light reaching the earth (~126'000 J/m²)
vec3 sunLuminance         = sunIlluminance / coneAngleToSolidAngle(sunAngularRad);

const vec3 moonLuminance = moonAlbedo * sunIlluminance;
vec3 moonIlluminance     = moonLuminance * coneAngleToSolidAngle(moonAngularRad); // The rough amount of light the moon emits that reaches the earth

float shadowLightAngularRad = sunAngle < 0.5 ? sunAngularRad : moonAngularRad;
