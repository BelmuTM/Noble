/***********************************************/
/*       Copyright (C) Noble SSRT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

float wTimeF = float(worldTime);
float timeSunrise = ((clamp(wTimeF, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(wTimeF, 0.0, 2000.0) / 2000.0));
float timeNoon = ((clamp(wTimeF, 0.0, 2000.0)) / 2000.0) - ((clamp(wTimeF, 10000.0, 12000.0) - 10000.0) / 2000.0);
float timeSunset = ((clamp(wTimeF, 10000.0, 12000.0) - 10000.0) / 2000.0) - ((clamp(wTimeF, 12500.0, 12750.0) - 12500.0) / 250.0);
float timeMidnight = ((clamp(wTimeF, 12500.0, 12750.0) - 12500.0) / 250.0) - ((clamp(wTimeF, 23000.0, 24000.0) - 23000.0) / 1000.0);

vec3 getDayTimeColor() {
    const vec3 ambient_sunrise = vec3(0.543, 0.272, 0.147);
    const vec3 ambient_noon = vec3(0.345, 0.302, 0.23);
    const vec3 ambient_sunset = vec3(0.543, 0.272, 0.147);
    const vec3 ambient_midnight = vec3(0.035, 0.25, 0.3);

    return ambient_sunrise * timeSunrise + ambient_noon * timeNoon + ambient_sunset * timeSunset + ambient_midnight * timeMidnight;
}

vec3 getDayTimeSunColor() {
    const vec3 sunColor_sunrise = vec3(0.30, 0.17, 0.045);
    const vec3 sunColor_noon = vec3(0.29, 0.22, 0.10);
    const vec3 sunColor_sunset = vec3(0.40, 0.17, 0.045);
    const vec3 sunColor_midnight = vec3(0.005, 0.05, 0.1);

    return sunColor_sunrise * timeSunrise + sunColor_noon * timeNoon + sunColor_sunset * timeSunset + sunColor_midnight * timeMidnight;
}