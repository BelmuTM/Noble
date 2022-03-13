/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec3 getDensities(float centerDist) {
	float altitudeKm = (centerDist - earthRad) * 1e-3;
	vec2 rayleighMie = exp(altitudeKm / -(scaleHeights * 1e-3));

    // Ozone approximation from Jessie#7257
    float o1 = 25.0 *     exp(( 0.0 - altitudeKm) /   8.0);
    float o2 = 30.0 * pow(exp((18.0 - altitudeKm) /  80.0), altitudeKm - 18.0);
    float o3 = 75.0 * pow(exp((25.3 - altitudeKm) /  35.0), altitudeKm - 25.3);
    float o4 = 50.0 * pow(exp((30.0 - altitudeKm) / 150.0), altitudeKm - 30.0);
    float ozone = (o1 + o2 + o3 + o4) / 134.628;

	return vec3(rayleighMie, ozone);
}

vec3 getVlDensities(in float height) {
    height -= VL_ALTITUDE;

    vec2 rayleighMie    = exp(-height / scaleHeights);
         rayleighMie.x *= mix(VL_DENSITY, VL_RAIN_DENSITY, rainStrength); // Increasing aerosols for VL to be unrealistically visible

    return vec3(rayleighMie, 0.0);
}
