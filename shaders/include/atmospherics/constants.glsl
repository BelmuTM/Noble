/********************************************************************************/
/*                                                                              */
/*    Noble Shaders                                                             */
/*    Copyright (C) 2025  Belmu                                                 */
/*                                                                              */
/*    This program is free software: you can redistribute it and/or modify      */
/*    it under the terms of the GNU General Public License as published by      */
/*    the Free Software Foundation, either version 3 of the License, or         */
/*    (at your option) any later version.                                       */
/*                                                                              */
/*    This program is distributed in the hope that it will be useful,           */
/*    but WITHOUT ANY WARRANTY; without even the implied warranty of            */
/*    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the             */
/*    GNU General Public License for more details.                              */
/*                                                                              */
/*    You should have received a copy of the GNU General Public License         */
/*    along with this program.  If not, see <https://www.gnu.org/licenses/>.    */
/*                                                                              */
/********************************************************************************/

/* ATMOSPHERIC CONSTANTS */

#if defined WORLD_OVERWORLD
    const float atmosphereLowerOffset = -1e3;
#else
    const float atmosphereLowerOffset = 0.0;
#endif

const float planetRadius          = 6371e3;                               // Meters
const float atmosphereLowerRadius = planetRadius + atmosphereLowerOffset; // Meters
const float atmosphereUpperRadius = planetRadius + 110e3;                 // Meters

const vec2 scaleHeights = vec2(8.40e3, 1.25e3); // Meters

const float mieScatteringAlbedo = 0.9;
const float mieAnisotropyFactor = 0.76;

const float airNumberDensity    = 2.5035422e25;
const float ozonePeakDensity    = 5e-6;
const float ozonePeakAltitude   = 35e3;
const float ozoneNumberDensity  = airNumberDensity * exp(-ozonePeakAltitude / 8e3) * (134.628 / 48.0) * ozonePeakDensity;
const float ozoneUnitConversion = 1e-4; // Converts from cm² to m²

const vec3 rayleighScatteringCoefficientsSunny = vec3(6.42905682e-6, 1.08663713e-5, 2.4844733e-5);
const vec3 mieScatteringCoefficientsSunny      = vec3(21e-6);

const vec3 rayleighScatteringCoefficientsRain = vec3(6.42e-5, 6.98e-5, 8.9e-5);
const vec3 mieScatteringCoefficientsRain      = vec3(1e-5);

#if defined IS_IRIS
    vec3 rayleighScatteringCoefficients = mix(rayleighScatteringCoefficientsSunny, rayleighScatteringCoefficientsRain, wetness * biome_may_rain);
    vec3 mieScatteringCoefficients      = mix(mieScatteringCoefficientsSunny, mieScatteringCoefficientsRain, wetness * biome_may_rain);
#else
    vec3 rayleighScatteringCoefficients = mix(rayleighScatteringCoefficientsSunny, rayleighScatteringCoefficientsRain, wetness);
    vec3 mieScatteringCoefficients      = mix(mieScatteringCoefficientsSunny, mieScatteringCoefficientsRain, wetness);
#endif

const vec3 ozoneExtinctionCoefficients = vec3(4.51103766177301e-21, 3.2854797958699e-21, 1.96774621921165e-22) * ozoneNumberDensity * ozoneUnitConversion;

const vec3 rayleighScatteringCoefficientsEnd = vec3(3e-5, 4e-6, 1e-5);
const vec3 mieScatteringCoefficientsEnd      = vec3(5.2e-3, 1e-6, 5e-3);
const vec3 rayleighExtinctionCoefficientsEnd = vec3(3e-5, 2e-4, 4e-5);
const vec3 mieExtinctionCoefficientsEnd      = vec3(7e-3, 2e-2, 9e-3) / mieScatteringAlbedo;

#if TONEMAP == ACES
    mat2x3 atmosphereScatteringCoefficients  = mat2x3(rayleighScatteringCoefficients * SRGB_2_AP1_ALBEDO,  mieScatteringCoefficients * SRGB_2_AP1_ALBEDO);
    mat3x3 atmosphereAttenuationCoefficients = mat3x3(rayleighScatteringCoefficients * SRGB_2_AP1_ALBEDO, (mieScatteringCoefficients * SRGB_2_AP1_ALBEDO) / mieScatteringAlbedo, ozoneExtinctionCoefficients * SRGB_2_AP1_ALBEDO);

    const mat2x3 atmosphereScatteringCoefficientsEnd  = mat2x3(rayleighScatteringCoefficientsEnd * SRGB_2_AP1_ALBEDO,  mieScatteringCoefficientsEnd * SRGB_2_AP1_ALBEDO);
    const mat3x3 atmosphereAttenuationCoefficientsEnd = mat3x3(rayleighScatteringCoefficientsEnd * SRGB_2_AP1_ALBEDO, (mieScatteringCoefficientsEnd * SRGB_2_AP1_ALBEDO) / mieScatteringAlbedo, vec3(0.0));
#else
    mat2x3 atmosphereScatteringCoefficients  = mat2x3(rayleighScatteringCoefficients, mieScatteringCoefficients);
    mat3x3 atmosphereAttenuationCoefficients = mat3x3(rayleighScatteringCoefficients, mieScatteringCoefficients / mieScatteringAlbedo, ozoneExtinctionCoefficients);

    const mat2x3 atmosphereScatteringCoefficientsEnd  = mat2x3(rayleighScatteringCoefficientsEnd, mieScatteringCoefficientsEnd);
    const mat3x3 atmosphereAttenuationCoefficientsEnd = mat3x3(rayleighExtinctionCoefficientsEnd, mieExtinctionCoefficientsEnd, vec3(0.0));
#endif

vec3 atmosphereRayPosition = vec3(0.0, planetRadius, 0.0) + cameraPosition;

/* CLOUDS CONSTANTS */

const float cloudsExtinctionCoefficient = 0.08;
const float cloudsScatteringCoefficient = 0.99;
const float cloudsTransmitThreshold     = 0.05;

const float cloudsForwardsLobe = 0.80;
const float cloudsBackardsLobe = 0.25;
const float cloudsForwardsPeak = 0.85;
const float cloudsBackScatter  = 0.20;
const float cloudsPeakWeight   = 0.10;

const int   cloudsMultiScatterSteps = 8;
const float cloudsExtinctionFalloff = 0.60;
const float cloudsScatteringFalloff = 0.50;
const float cloudsAnisotropyFalloff = 0.80;

/* FOG CONSTANTS */

const float airFogExtinctionCoefficient = 0.1;
const float airFogScatteringCoefficient = 0.99;

const float airFogForwardsLobe = 0.35;
const float airFogBackardsLobe = 0.35;
const float airFogForwardsPeak = 0.90;
const float airFogBackScatter  = 0.15;
const float airFogPeakWeight   = 0.25;

/* CELESTIAL CONSTANTS */

vec3 starVector = normalize(sphericalToCartesian(25.0, 45.0));

const float sunRadius   = 6.9634e8;
const float sunDistance = 1.496e11;

const float moonRadius    = 1.7374e6;
const float moonDistance  = 3.8440e8;
const float moonAlbedo    = 0.136; // The full moon reflects approximately 13-14% of the sun's emitted light 
const float moonRoughness = 0.40;

const float starRadius   = 3.171e11;
const float starDistance = 6.07852e12;

const float sunAngularRadius  = CELESTIAL_SIZE_MULTIPLIER * sunRadius  / sunDistance;
const float moonAngularRadius = CELESTIAL_SIZE_MULTIPLIER * moonRadius / moonDistance;
const float starAngularRadius = CELESTIAL_SIZE_MULTIPLIER * starRadius / starDistance;

const vec3 sunIrradiance = vec3(1.0, 0.949, 0.937) * 126e3; // Brightness of light reaching the earth (~126'000 J/m²)
      vec3 sunRadiance   = sunIrradiance / coneAngleToSolidAngle(sunAngularRadius);

const vec3 moonRadiance   = moonAlbedo * sunIrradiance;
      vec3 moonIrradiance = moonRadiance * coneAngleToSolidAngle(moonAngularRadius); // The rough amount of light the moon emits that reaches the earth

vec3 starIrradiance = blackbody(25000.0) * 500.0;
vec3 starRadiance   = starIrradiance / coneAngleToSolidAngle(starAngularRadius);

float shadowLightAngularRadius = sunAngle < 0.5 ? sunAngularRadius : moonAngularRadius;
