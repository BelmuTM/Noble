/***********************************************/
/*           Copyright (C) 2023 Belmu          */
/*             All Rights Reserved             */
/***********************************************/

/* ATMOSPHERIC CONSTANTS */

const float mieAnisotropyFactor = 0.76;
const float isotropicPhase      = 0.07957747;

const float planetRadius          = 6371e3;               // Meters
const float atmosphereLowerRadius = planetRadius - 4e3;   // Meters
const float atmosphereUpperRadius = planetRadius + 110e3; // Meters

const vec2 scaleHeights = vec2(8.40e3, 1.25e3); // Meters

const float mieAlbedo = 0.9;

#if TONEMAP == 0
    const vec3 rayleighScatteringCoefficient = vec3(6.42905682e-6, 1.08663713e-5, 2.4844733e-5)                                     * SRGB_2_AP1_ALBEDO;
    const vec3 mieScatteringCoefficient      = vec3(0.00000925288)                                                                  * SRGB_2_AP1_ALBEDO;
    const vec3 ozoneScatteringCoefficient    = vec3(4.51103766177301e-21, 3.2854797958699e-21, 1.96774621921165e-22) * 3.5356617e14 * SRGB_2_AP1_ALBEDO;
#else
    const vec3 rayleighScatteringCoefficient = vec3(6.42905682e-6, 1.08663713e-5, 2.4844733e-5);
    const vec3 mieScatteringCoefficient      = vec3(0.00000925288);
    const vec3 ozoneScatteringCoefficient    = vec3(4.51103766177301e-21, 3.2854797958699e-21, 1.96774621921165e-22) * 3.5356617e14;
#endif

mat2x3 atmosphereScatteringCoefficients = mat2x3(rayleighScatteringCoefficient, mieScatteringCoefficient);
mat3x3 atmosphereExtinctionCoefficients = mat3x3(rayleighScatteringCoefficient, mieScatteringCoefficient / mieAlbedo, ozoneScatteringCoefficient);

vec3 atmosphereRayPosition = vec3(0.0, planetRadius, 0.0) + cameraPosition;

/* CLOUDS CONSTANTS */

float       cloudsExtinctionCoefficient = mix(0.15, 0.3, wetness);
const float cloudsScatteringCoefficient = 1.0;
const float cloudsTransmitThreshold     = 5e-2;

const float cloudsForwardsLobe = 0.35;
const float cloudsBackardsLobe = 0.35;
const float cloudsForwardsPeak = 0.90;
const float cloudsBackScatter  = 0.20;
const float cloudsPeakWeight   = 0.15;

const int   cloudsMultiScatterSteps = 8;
const float cloudsExtinctionFalloff = 0.60;
const float cloudsScatteringFalloff = 0.55;
const float cloudsAnisotropyFalloff = 0.80;

/* FOG CONSTANTS */

const float fogExtinctionCoefficient = 0.06;
const float fogScatteringCoefficient = 0.3;

const float fogForwardsLobe = 0.45;
const float fogBackardsLobe = 0.45;
const float fogForwardsPeak = 0.90;
const float fogBackScatter  = 0.15;
const float fogPeakWeight   = 0.25;

/* CELESTIAL CONSTANTS */

const float moonRadius    = 1.7374e6;
const float moonDistance  = 3.8440e8;
const float moonAlbedo    = 0.136; // The moon reflects approximately 12-13% of the sun's emitted light 
const float moonRoughness = 0.40;

const float sunRadius   = 6.9634e8;
const float sunDistance = 1.496e11;

const float sunAngularRadius  = CELESTIAL_SIZE_MULTIPLIER * sunRadius  / sunDistance;
const float moonAngularRadius = CELESTIAL_SIZE_MULTIPLIER * moonRadius / moonDistance;

const vec3 sunColor = vec3(1.0, 0.949, 0.937);
vec3 sunIlluminance = (sunColor / luminance(sunColor)) * 126e3; // Brightness of light reaching the earth (~126'000 J/m²)
vec3 sunLuminance   = sunIlluminance / coneAngleToSolidAngle(sunAngularRadius);

vec3 moonLuminance   = moonAlbedo * RCP_PI * sunIlluminance;
vec3 moonIlluminance = moonLuminance * coneAngleToSolidAngle(moonAngularRadius); // The rough amount of light the moon emits that reaches the earth

float shadowLightAngularRadius = sunAngle < 0.5 ? sunAngularRadius : moonAngularRadius;
