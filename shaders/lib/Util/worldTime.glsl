/***********************************************/
/*       Copyright (C) Noble RT - 2021       */
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
	vec2 coord = planeCoords.xz * 0.4 + cameraPosition.xz * 0.0001 + frameTime * 0.00125;
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

vec3 getDayTimeColor() {
    const vec3 ambient_sunrise  = vec3(0.843, 0.372, 0.147);
    const vec3 ambient_noon     = vec3(0.945, 0.902, 0.830);
    const vec3 ambient_sunset   = vec3(0.843, 0.372, 0.147);
    const vec3 ambient_midnight = vec3(0.254, 0.284, 0.291);

    return ambient_sunrise * timeSunrise + ambient_noon * timeNoon + ambient_sunset * timeSunset + ambient_midnight * timeMidnight;
}

vec3 getDayTimeSkyGradient(in vec3 pos, vec3 viewPos) {  // Bottom Color -> Top Color
    pos.y += bayer2(gl_FragCoord.xy);
    vec3 skyGradient_sunrise  = mix(vec3(0.529, 0.292, 0.047),    vec3(0.20, 0.386, 0.682),     pos.y);
    vec3 skyGradient_noon     = mix(vec3(0.424, 0.532, 0.702),    vec3(0.20, 0.386, 0.682),     pos.y);
    vec3 skyGradient_sunset   = mix(vec3(0.529, 0.112, 0.047),    vec3(0.20, 0.386, 0.682),     pos.y);
    vec3 skyGradient_midnight = mix(vec3(0.0146, 0.0244, 0.0402), vec3(0.0048, 0.0087, 0.0122), pos.y) + drawStars(viewPos);

    return skyGradient_sunrise * timeSunrise + skyGradient_noon * timeNoon + skyGradient_sunset * timeSunset + skyGradient_midnight * timeMidnight;
}
