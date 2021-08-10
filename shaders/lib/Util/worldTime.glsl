/***********************************************/
/*       Copyright (C) Noble RT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

float wTimeF = float(worldTime);
float timeSunrise  = ((clamp(wTimeF, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(wTimeF, 0.0, 2000.0) / 2000.0));
float timeNoon     = ((clamp(wTimeF, 0.0, 2000.0)) / 2000.0) - ((clamp(wTimeF, 10000.0, 12000.0) - 10000.0) / 2000.0);
float timeSunset   = ((clamp(wTimeF, 10000.0, 12000.0) - 10000.0) / 2000.0) - ((clamp(wTimeF, 12500.0, 12750.0) - 12500.0) / 250.0);
float timeMidnight = ((clamp(wTimeF, 12500.0, 12750.0) - 12500.0) / 250.0) - ((clamp(wTimeF, 23000.0, 24000.0) - 23000.0) / 1000.0);

vec3 getDayTimeColor() {
    const vec3 ambient_sunrise  = vec3(0.843, 0.372, 0.147);
    const vec3 ambient_noon     = vec3(0.845, 0.802, 0.73);
    const vec3 ambient_sunset   = vec3(0.843, 0.372, 0.147);
    const vec3 ambient_midnight = vec3(0.2, 0.25, 0.45);

    return ambient_sunrise * timeSunrise + ambient_noon * timeNoon + ambient_sunset * timeSunset + ambient_midnight * timeMidnight;
}

vec3 getDayTimeSkyGradient(float x) {  // Bottom Color -> Top Color
    vec3 skyGradient_sunrise  = mix(vec3(0.529, 0.192, 0.047), vec3(0.275, 0.675, 0.91), x);
    vec3 skyGradient_noon     = mix(vec3(0.275, 0.675, 0.91), vec3(0.275, 0.675, 0.91), x);
    vec3 skyGradient_sunset   = mix(vec3(0.275, 0.675, 0.91), vec3(0.275, 0.675, 0.91), x);
    vec3 skyGradient_midnight = mix(vec3(0.529, 0.192, 0.047), vec3(0.275, 0.675, 0.91), x);

    return skyGradient_sunrise * timeSunrise + skyGradient_noon * timeNoon + skyGradient_sunset * timeSunset + skyGradient_midnight * timeMidnight;
}