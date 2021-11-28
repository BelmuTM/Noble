/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

float timeMidnight = ((clamp(float(worldTime), 12500.0, 12750.0) - 12500.0) / 250.0) - 
                     ((clamp(float(worldTime), 23000.0, 24000.0) - 23000.0) / 1000.0);

vec3 celestialBody(vec3 viewDir, vec3 lightDir) {
    float VdotL = dot(viewDir, lightDir);
    
    vec3 sun  = VdotL < cos(sunAngularRad)  ? vec3(0.0) : blackbody(sunTemp);
    vec3 moon = VdotL < cos(moonAngularRad) ? vec3(0.0) : moonAlbedo + (10.0 * timeMidnight);

    return worldTime <= 12750 ? sun : moon;
}

// Originally written by Capt Tatsu#7124
// Modified by Belmu#4066
float starfield(vec3 viewPos) {
	vec3 playerPos = mat3(gbufferModelViewInverse) * viewPos;
	vec3 planeCoords = playerPos / (playerPos.y + length(playerPos.xz));
	vec2 coord = planeCoords.xz * 0.7 + cameraPosition.xz * 1e-5 + frameTime * 0.00125;
	coord = floor(coord * 1024.0) / 1024.0;

	float VdotU = clamp01(dot(normalize(viewPos), normalize(upPosition)));
	float multiplier = sqrt(sqrt(VdotU)) * (1.0 - rainStrength);

	float star = 1.0;
	if(VdotU > 0.0) {
		star *= rand(coord.xy);
		star *= rand(-coord.xy + 0.1);
	}
	return clamp01(star - (1.0 - STARS_AMOUNT)) * multiplier;
}
