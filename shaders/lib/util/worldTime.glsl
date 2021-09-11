/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

float wTime = float(worldTime);
float timeSunrise  = ((clamp(wTime, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(wTime, 0.0, 2000.0) / 2000.0));
float timeNoon     = ((clamp(wTime, 0.0, 2000.0)) / 2000.0) - ((clamp(wTime, 10000.0, 12000.0) - 10000.0) / 2000.0);
float timeSunset   = ((clamp(wTime, 10000.0, 12000.0) - 10000.0) / 2000.0) - ((clamp(wTime, 12500.0, 12750.0) - 12500.0) / 250.0);
float timeMidnight = ((clamp(wTime, 12500.0, 12750.0) - 12500.0) / 250.0) - ((clamp(wTime, 23000.0, 24000.0) - 23000.0) / 1000.0);

/* 
	Originally written by Capt Tatsu#7124
	Modified by Belmu
*/
float drawStars(vec3 viewPos) {
	vec3 worldPos = mat3(gbufferModelViewInverse) * viewPos;
	vec3 planeCoords = worldPos / (worldPos.y + length(worldPos.xz));
	vec2 coord = planeCoords.xz * 0.5 + cameraPosition.xz * 0.0001 + frameTime * 0.00125;
	coord = floor(coord * 1024.0) / 1024.0;

	float VdotU = saturate(dot(normalize(viewPos), normalize(upPosition)));
	float multiplier = sqrt(sqrt(VdotU)) * (1.0 - rainStrength);

	float star = 1.0;
	if(VdotU > 0.0) {
		star *= rand(coord.xy);
		star *= rand(coord.xy + 0.10);
		star *= rand(coord.xy + 0.23);
	}
	star = saturate(star - 0.8125) * multiplier;
	return star;
}

vec3 getDayColor() {
    const vec3 ambient_sunrise  = vec3(0.843, 0.372, 0.147);
    const vec3 ambient_noon     = vec3(0.975, 0.932, 0.860);
    const vec3 ambient_sunset   = vec3(0.843, 0.372, 0.147);
    const vec3 ambient_midnight = vec3(0.164, 0.194, 0.201);

    return ambient_sunrise * timeSunrise + ambient_noon * timeNoon + ambient_sunset * timeSunset + ambient_midnight * timeMidnight;
}

vec3 getSunColor() {
    const vec3 sunColor_sunrise  = vec3(0.843, 0.372, 0.147);
    const vec3 sunColor_noon     = vec3(0.945, 0.902, 0.830);
    const vec3 sunColor_sunset   = vec3(0.843, 0.372, 0.147);
    const vec3 sunColor_midnight = vec3(0.095, 0.132, 0.330);

    return sunColor_sunrise * timeSunrise + sunColor_noon * timeNoon + sunColor_sunset * timeSunset + sunColor_midnight * timeMidnight;
}

vec3 getDayTimeSkyGradient(in vec3 pos, vec3 viewPos) {  // Bottom Color -> Top Color
    vec3 skyGradient_sunrise  = mix(vec3(0.529, 0.34, 0.247),  vec3(0.23, 0.265, 0.339),  pos.y);
    vec3 skyGradient_noon     = mix(vec3(0.424, 0.532, 0.702), vec3(0.22, 0.345, 0.439),  pos.y);
    vec3 skyGradient_sunset   = mix(vec3(0.529, 0.3, 0.22),    vec3(0.23, 0.265, 0.339),  pos.y);
    vec3 skyGradient_midnight = mix(vec3(0.03, 0.069, 0.108),  vec3(0.001, 0.007, 0.031), pos.y) + (drawStars(viewPos) * 2.0);

    return skyGradient_sunrise * timeSunrise + skyGradient_noon * timeNoon + skyGradient_sunset * timeSunset + skyGradient_midnight * timeMidnight;
}
