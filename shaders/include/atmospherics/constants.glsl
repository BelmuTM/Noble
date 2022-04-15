/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* ATMOSPHERE CONSTANTS */
const float anisotropyFactor = 0.76;

const float earthRad      = 6371e3;           // meters
const float atmosLowerRad = earthRad - 3e3;   // meters
const float atmosUpperRad = earthRad + 110e3; // meters

const vec2 scaleHeights = vec2(8.40e3, 1.25e3); // meters

/* CLOUDS CONSTANTS */
const float innerCloudRad = earthRad      + CLOUDS_ALTITUDE;
const float outerCloudRad = innerCloudRad + CLOUDS_THICKNESS;
const float windAngleRad  = 0.785398;

const int cloudsMultiScatterSteps = 6;

const float cloudsExtinctionCoeff   = 0.1;
const float cloudsScatteringCoeff   = 1.0;
const float cloudsTransmitThreshold = 5e-2;

const float cloudsForwardsLobe = 0.40;
const float cloudsBackardsLobe = 0.35;
const float cloudsForwardsPeak = 0.90;
const float cloudsBackScatter  = 0.20;
const float cloudsPeakWeight   = 0.15;

const float cloudsExtinctionFalloff = 0.5;
const float cloudsScatteringFalloff = 0.5;
const float cloudsAnisotropyFalloff = 0.6;

const float cloudsShadowmapRes  = 1024.0;
const float cloudsShadowmapDist = 600.0;

// Coefficients provided by Jessie#7257 and LVutner#5199

#if TONEMAP == 0
    vec3 rayleighCoeff = linearToAP1(vec3(5.8, 13.3, 33.31)    * 1e-6);
    vec3 mieCoeff      = linearToAP1(vec3(21.0)                * 1e-6);
    vec3 ozoneCoeff    = linearToAP1(vec3(8.30428e-07, 1.31491e-06, 5.44068e-08));
#else
    vec3 rayleighCoeff = vec3(5.8, 13.3, 33.31)    * 1e-6;
    vec3 mieCoeff      = vec3(21.0)                * 1e-6;
    vec3 ozoneCoeff    = vec3(8.30428e-07, 1.31491e-06, 5.44068e-08);
#endif

mat2x3 atmosScatteringCoeff = mat2x3(rayleighCoeff, mieCoeff);
mat3x3 atmosExtinctionCoeff = mat3x3(rayleighCoeff, mieCoeff * 1.11, ozoneCoeff);

vec3 atmosRayPos = vec3(0.0, earthRad, 0.0) + cameraPosition;

const float isotropicPhase   = 0.07957747;
const float atmosEnergyParam = 3e3;

/* CELESTIAL CONSTANTS */
const float moonRad       = 1.7374e3;
const float moonDist      = 3.8440e5;
const float moonAlbedo    = 0.12;
const float moonRoughness = 0.40;

const float sunRad  = 6.9634e8;
const float sunDist = 1.496e11;
const float sunTemp = 5778.0;

const float sunAngularRad  = CELESTIAL_SIZE_MULTIPLIER * sunRad  / sunDist;
const float moonAngularRad = CELESTIAL_SIZE_MULTIPLIER * moonRad / moonDist;

vec3 sunIlluminance = vec3(1.0, 0.949, 0.937) * 126e3; // Brightness of light reaching the earth (J/m²)
vec3 sunLuminance   = sunIlluminance / (TAU * (1.0 - cos(sunAngularRad)));

vec3 moonLuminance   = moonAlbedo * sunIlluminance;
vec3 moonIlluminance = moonLuminance * (TAU * (1.0 - cos(moonAngularRad))); // The rough amount of light the moon emits that reaches the earth

float shadowLightAngularRad = sunAngle < 0.5 ? sunAngularRad : moonAngularRad;
