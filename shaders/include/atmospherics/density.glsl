/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec3 densities(float height) {
    vec2 rayleighMie = exp(-height / vec2(hR, hM));
    float ozone      = exp(-max0((35e3 - height) - atmosRad) / 5e3) * exp(-max0((height - 35e3) - atmosRad) / 15e3);
    return vec3(rayleighMie, ozone);
}

vec3 vlDensities(in float height) {
    height -= VL_ALTITUDE;

    vec2 rayleighMie    = exp(-height / vec2(hR, hM));
         rayleighMie.x *= mix(VL_DENSITY, VL_RAIN_DENSITY, rainStrength); // Increasing aerosols for VL to be unrealistically visible

    return vec3(rayleighMie, 0.0);
}
