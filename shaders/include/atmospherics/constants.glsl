/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* ATMOSPHERE CONSTANTS */
const float g  = 0.76;
const float gg = g*g;

const float earthRad = 6371e3;
const float atmosRad = 6481e3;

const float hR = 8.0e3;
const float hM = 1.2e3;

// Coefficients provided by Jessie#7257 and LVutner#5199
const vec3 kRlh   = vec3(5.8e-6, 13.3e-6, 33.31e-6);
const mat2x3 kMie = mat2x3(vec3(21e-6), vec3(21e-6) * 1.11);
const vec3 kOzo   = vec3(3.426e-7, 8.298e-7, 0.356e-7);

const mat2x3 kScattering = mat2x3(kRlh, kMie[0]);
const mat3x3 kExtinction = mat3x3(kRlh, kMie[0] + kMie[1], kOzo);

const vec3 atmosRayPos = vec3(0.0, earthRad, 0.0);

/* CELESTIAL CONSTANTS */
const float moonRad    = 1.7374e3;
const float moonDist   = 3.8440e5;
const float moonAlbedo = 0.12;

const float sunRad  = 6.9634e8;
const float sunDist = 1.496e11;
const float sunTemp = 5778.0;

const float sunAngularRad  = CELESTIAL_SIZE_MULTIPLIER * sunRad  / sunDist;
const float moonAngularRad = CELESTIAL_SIZE_MULTIPLIER * moonRad / moonDist;

const vec3 sunIlluminance = vec3(1.0, 0.949, 0.937) * 120e3; // Brightness of light reaching the earth
const vec3 sunLuminance   = sunIlluminance / (TAU * (1.0 - cos(sunAngularRad)));

const vec3 moonIlluminance = vec3(moonAlbedo);
const vec3 moonLuminance   = moonIlluminance / (TAU * (1.0 - cos(moonAngularRad)));
