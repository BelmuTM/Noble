/***********************************************/
/*           Copyright (C) 2023 Belmu          */
/*             All Rights Reserved             */
/***********************************************/

/* ATMOSPHERIC CONSTANTS */

const float planetRadius          = 6371e3;               // Meters
const float atmosphereLowerRadius = planetRadius - 3e3;   // Meters
const float atmosphereUpperRadius = planetRadius + 110e3; // Meters

const vec2 scaleHeights = vec2(8.40e3, 1.25e3); // Meters

const float mieScatteringAlbedo = 0.9;
const float mieAnisotropyFactor = 0.76;

const float airNumberDensity    = 2.5035422e25;
const float ozonePeakDensity    = 5e-6;
const float ozonePeakAltitude   = 35e3;
const float ozoneNumberDensity  = airNumberDensity * exp(-ozonePeakAltitude / 8e3) * (134.628 / 48.0) * ozonePeakDensity;
const float ozoneUnitConversion = 1e-4; // Converts from cm² to m²

const vec3 rayleighScatteringCoefficients = vec3(6.42905682e-6, 1.08663713e-5, 2.4844733e-5);
const vec3 mieScatteringCoefficients      = vec3(9.25288e-6);
const vec3 ozoneExtinctionCoefficients    = vec3(4.51103766177301e-21, 3.2854797958699e-21, 1.96774621921165e-22) * ozoneNumberDensity * ozoneUnitConversion;

const vec3 rayleighScatteringCoefficientsEnd = vec3(7e-2, 4e-6, 1e-10);
const vec3 mieScatteringCoefficientsEnd      = vec3(1.3e-3);
const vec3 gasExtinctionCoefficientsEnd      = vec3(8e-5, 3e-8, 1e-15) * 3.5e3;

#if TONEMAP == ACES
    const mat2x3 atmosphereScatteringCoefficients  = mat2x3(rayleighScatteringCoefficients * SRGB_2_AP1_ALBEDO,  mieScatteringCoefficients * SRGB_2_AP1_ALBEDO);
    const mat3x3 atmosphereAttenuationCoefficients = mat3x3(rayleighScatteringCoefficients * SRGB_2_AP1_ALBEDO, (mieScatteringCoefficients * SRGB_2_AP1_ALBEDO) / mieScatteringAlbedo, ozoneExtinctionCoefficients * SRGB_2_AP1_ALBEDO);

    const mat2x3 atmosphereScatteringCoefficientsEnd  = mat2x3(rayleighScatteringCoefficientsEnd * SRGB_2_AP1_ALBEDO,  mieScatteringCoefficientsEnd * SRGB_2_AP1_ALBEDO);
    const mat3x3 atmosphereAttenuationCoefficientsEnd = mat3x3(rayleighScatteringCoefficientsEnd * SRGB_2_AP1_ALBEDO, (mieScatteringCoefficientsEnd * SRGB_2_AP1_ALBEDO) / mieScatteringAlbedo, gasExtinctionCoefficientsEnd * SRGB_2_AP1_ALBEDO);
#else
    const mat2x3 atmosphereScatteringCoefficients  = mat2x3(rayleighScatteringCoefficients, mieScatteringCoefficients);
    const mat3x3 atmosphereAttenuationCoefficients = mat3x3(rayleighScatteringCoefficients, mieScatteringCoefficients / mieScatteringAlbedo, ozoneExtinctionCoefficients);

    const mat2x3 atmosphereScatteringCoefficientsEnd  = mat2x3(rayleighScatteringCoefficientsEnd, mieScatteringCoefficientsEnd);
    const mat3x3 atmosphereAttenuationCoefficientsEnd = mat3x3(rayleighScatteringCoefficientsEnd, mieScatteringCoefficientsEnd / mieScatteringAlbedo, gasExtinctionCoefficientsEnd);
#endif

vec3 atmosphereRayPosition = vec3(0.0, planetRadius, 0.0) + cameraPosition;

/* CLOUDS CONSTANTS */

      float cloudsExtinctionCoefficient = 0.1;
const float cloudsScatteringCoefficient = 0.99;
const float cloudsTransmitThreshold     = 5e-2;

const float cloudsForwardsLobe = 0.40;
const float cloudsBackardsLobe = 0.40;
const float cloudsForwardsPeak = 0.90;
const float cloudsBackScatter  = 0.20;
const float cloudsPeakWeight   = 0.15;

const int   cloudsMultiScatterSteps = 8;
const float cloudsExtinctionFalloff = 0.60;
const float cloudsScatteringFalloff = 0.50;
const float cloudsAnisotropyFalloff = 0.80;

/* FOG CONSTANTS */

const float airFogExtinctionCoefficient = 0.06;
const float airFogScatteringCoefficient = 0.3;

const float airFogForwardsLobe = 0.35;
const float airFogBackardsLobe = 0.35;
const float airFogForwardsPeak = 0.90;
const float airFogBackScatter  = 0.15;
const float airFogPeakWeight   = 0.25;

/* CELESTIAL CONSTANTS */

const float starAzimuth  = -0.25;
const float starZenith   =  0.45;
const float starAltitude =  0.45;

vec3 starVector = normalize(vec3(starAzimuth, starZenith, starAltitude));

const float sunRadius   = 6.9634e8;
const float sunDistance = 1.496e11;

const float moonRadius    = 1.7374e6;
const float moonDistance  = 3.8440e8;
const float moonAlbedo    = 0.136; // The full moon reflects approximately 13-14% of the sun's emitted light 
const float moonRoughness = 0.40;

const float starRadius   = 6.171e11;
const float starDistance = 6.07852e12;

const float sunAngularRadius  = CELESTIAL_SIZE_MULTIPLIER * sunRadius  / sunDistance;
const float moonAngularRadius = CELESTIAL_SIZE_MULTIPLIER * moonRadius / moonDistance;
const float starAngularRadius = CELESTIAL_SIZE_MULTIPLIER * starRadius / starDistance;

const vec3 sunIrradiance = vec3(1.0, 0.949, 0.937) * 126e3; // Brightness of light reaching the earth (~126'000 J/m²)
      vec3 sunRadiance   = sunIrradiance / coneAngleToSolidAngle(sunAngularRadius);

const vec3 moonRadiance   = moonAlbedo * sunIrradiance;
      vec3 moonIrradiance = moonRadiance * coneAngleToSolidAngle(moonAngularRadius); // The rough amount of light the moon emits that reaches the earth

vec3 starIrradiance = blackbody(25000.0) * 100.0;
vec3 starRadiance   = starIrradiance / coneAngleToSolidAngle(starAngularRadius);

float shadowLightAngularRadius = sunAngle < 0.5 ? sunAngularRadius : moonAngularRadius;
