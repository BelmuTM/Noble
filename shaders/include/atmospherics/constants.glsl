/********************************************************************************/
/*                                                                              */
/*    Noble Shaders                                                             */
/*    Copyright (C) 2026  Belmu                                                 */
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

/*
    [References]:
        Serdyuchenko et al. (2014). High spectral resolution ozone absorption cross-sections – Part 1: Measurements, data analysis and comparison with previous measurements around 293 K. https://amt.copernicus.org/articles/7/609/2014/amt-7-609-2014.pdf
*/

/* ATMOSPHERIC CONSTANTS */

#if defined WORLD_OVERWORLD
    const float atmosphereLowerOffset = -5e3;
#else
    const float atmosphereLowerOffset = 0.0;
#endif

const float planetRadius          = 6371e3;                               // Meters (m)
const float atmosphereLowerRadius = planetRadius + atmosphereLowerOffset; // Meters (m)
const float atmosphereUpperRadius = planetRadius + 110e3;                 // Meters (m)

const vec2 scaleHeights = vec2(8.40e3, 1.25e3); // Meters (m)

const float mieScatteringAlbedo = 0.9;
const float mieAnisotropyFactor = 2346.25355; // energy term e (unitless)

const float ozonePeakDensity    = 5e-6; // Parts per million (ppm)
const float ozonePeakAltitude   = 35e3; // Kilometers (km)
const float ozoneUnitConversion = 1e-4; // Converts from cm² to m²

const float airNumberDensity    = 2.5035422e25;
const float ozoneNumberDensity  = airNumberDensity * exp(-ozonePeakAltitude / 8e3) * ozonePeakDensity;

// Coefficients in cm²/molecule

const vec3 rayleighScatteringCoefficientsSunny = vec3(6.42905682e-6, 1.08663713e-5, 2.4844733e-5);
const vec3 mieScatteringCoefficientsSunny      = vec3(22e-6);

const vec3 rayleighScatteringCoefficientsRain = vec3(6.42e-5, 6.98e-5, 8.9e-5);
const vec3 mieScatteringCoefficientsRain      = vec3(1e-5);

vec3 rayleighScatteringCoefficients = mix(rayleighScatteringCoefficientsSunny, rayleighScatteringCoefficientsRain, wetness * biome_may_rain);
vec3 mieScatteringCoefficients      = mix(mieScatteringCoefficientsSunny     , mieScatteringCoefficientsRain     , wetness * biome_may_rain);

const vec3 ozoneExtinctionCoefficients = vec3(4.51103e-21, 3.28547e-21, 5.36774e-22) * ozoneNumberDensity * ozoneUnitConversion;

const vec3 rayleighScatteringCoefficientsEnd = vec3(3e-5, 4e-6, 1e-5);
const vec3 mieScatteringCoefficientsEnd      = vec3(5.2e-3, 7e-3, 5e-3);
const vec3 rayleighExtinctionCoefficientsEnd = vec3(3e-5, 2e-4, 4e-5);
const vec3 mieExtinctionCoefficientsEnd      = vec3(7e-3, 2e-2, 9e-3) / mieScatteringAlbedo;

mat2x3 atmosphereScatteringCoefficients = mat2x3(
    SRGB_TO_WORKING_SPACE_ALBEDO(rayleighScatteringCoefficients),
    SRGB_TO_WORKING_SPACE_ALBEDO(mieScatteringCoefficients)
);

mat3x3 atmosphereAttenuationCoefficients = mat3x3(
    SRGB_TO_WORKING_SPACE_ALBEDO(rayleighScatteringCoefficients),
    SRGB_TO_WORKING_SPACE_ALBEDO(mieScatteringCoefficients / mieScatteringAlbedo),
    SRGB_TO_WORKING_SPACE_ALBEDO(ozoneExtinctionCoefficients)
);

const mat2x3 atmosphereScatteringCoefficientsEnd = mat2x3(
    SRGB_TO_WORKING_SPACE_ALBEDO(rayleighScatteringCoefficientsEnd),
    SRGB_TO_WORKING_SPACE_ALBEDO(mieScatteringCoefficientsEnd)
);

const mat3x3 atmosphereAttenuationCoefficientsEnd = mat3x3(
    SRGB_TO_WORKING_SPACE_ALBEDO(rayleighExtinctionCoefficientsEnd),
    SRGB_TO_WORKING_SPACE_ALBEDO(mieExtinctionCoefficientsEnd),
    vec3(0.0)
);

vec3 atmosphereRayPosition = vec3(0.0, planetRadius, 0.0) + cameraPosition;

/* CLOUDS CONSTANTS */

const float cloudsFallbackDistance = 65534.0;

const float cloudsExtinctionCoefficient = 0.05;
const float cloudsScatteringCoefficient = 0.99;
const float cloudsTransmitThreshold     = 0.05;

const float cloudsForwardsLobe = 0.80;
const float cloudsBackardsLobe = 0.25;
const float cloudsForwardsPeak = 0.85;
const float cloudsBackScatter  = 0.20;
const float cloudsPeakWeight   = 0.10;

const int   cloudsMultiScatterSteps = 8;
const float cloudsExtinctionFalloff = 0.70;
const float cloudsScatteringFalloff = 0.60;
const float cloudsAnisotropyFalloff = 0.80;

/* FOG CONSTANTS */

const float airFogExtinctionCoefficient = 0.1;
const float airFogScatteringCoefficient = 0.99;

const float airFogForwardsLobe = 0.75;
const float airFogBackardsLobe = 0.20;
const float airFogForwardsPeak = 0.95;
const float airFogBackScatter  = 0.08;
const float airFogPeakWeight   = 0.35;

/* CELESTIAL CONSTANTS */

// End star

const float azimuthStar  = 25.0;
const float altitudeStar = 45.0;

const float phi_star   = radians(azimuthStar);
const float theta_star = radians(90.0 - altitudeStar);

const vec3 starVector = normalize(vec3(sin(theta_star) * cos(phi_star), cos(theta_star), sin(theta_star) * sin(phi_star)));

const float starRadius   = 3.171e11;
const float starDistance = 6.07852e12;

// Sun

const float sunRadius   = 6.9634e8;
const float sunDistance = 1.496e11;

// Moon

const float moonRadius    = 1.7374e6;
const float moonDistance  = 3.8440e8;
const float moonAlbedo    = 0.136; // The full moon reflects approximately 13-14% of the sun's emitted light 
const float moonRoughness = 0.40;

// Angular radii

const float sunAngularRadius  = CELESTIAL_SIZE_MULTIPLIER * sunRadius  / sunDistance;
const float moonAngularRadius = CELESTIAL_SIZE_MULTIPLIER * moonRadius / moonDistance;
const float starAngularRadius = CELESTIAL_SIZE_MULTIPLIER * starRadius / starDistance;

float shadowLightAngularRadius = sunAngle < 0.5 ? sunAngularRadius : moonAngularRadius;

// Photometric constants

// Brightness of light reaching the earth (~126'000 lux)
const vec3 sunIlluminance = vec3(1.0, 0.949, 0.937) * 126e3;
const vec3 sunLuminance   = sunIlluminance / coneAngleToSolidAngle(sunAngularRadius / CELESTIAL_SIZE_MULTIPLIER);

const vec3 moonLuminance   = moonAlbedo * sunIlluminance;
// The rough amount of light the moon emits that reaches the earth
const vec3 moonIlluminance = moonLuminance * coneAngleToSolidAngle(moonAngularRadius / CELESTIAL_SIZE_MULTIPLIER);

vec3 starIlluminance = blackbody(25000.0) * 500.0;
vec3 starLuminance   = starIlluminance / coneAngleToSolidAngle(starAngularRadius);
