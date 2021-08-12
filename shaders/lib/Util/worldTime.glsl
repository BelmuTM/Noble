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
    const vec3 ambient_noon     = vec3(0.945, 0.902, 0.830);
    const vec3 ambient_sunset   = vec3(0.843, 0.372, 0.147);
    const vec3 ambient_midnight = vec3(0.254, 0.284, 0.291);

    return ambient_sunrise * timeSunrise + ambient_noon * timeNoon + ambient_sunset * timeSunset + ambient_midnight * timeMidnight;
}

vec3 getDayTimeSkyGradient(float x) {  // Bottom Color -> Top Color
    x += bayer2(gl_FragCoord.xy);
    vec3 skyGradient_sunrise  = mix(vec3(0.529, 0.292, 0.047),    vec3(0.20, 0.386, 0.582),     x);
    vec3 skyGradient_noon     = mix(vec3(0.424, 0.532, 0.702),    vec3(0.20, 0.386, 0.582),     x);
    vec3 skyGradient_sunset   = mix(vec3(0.529, 0.112, 0.047),    vec3(0.20, 0.386, 0.582),     x);
    vec3 skyGradient_midnight = mix(vec3(0.0146, 0.0244, 0.0402), vec3(0.0048, 0.0087, 0.0122), x);

    return skyGradient_sunrise * timeSunrise + skyGradient_noon * timeNoon + skyGradient_sunset * timeSunset + skyGradient_midnight * timeMidnight;
}