/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec3 getViewPos(vec2 coords) {
    vec3 clipPos = vec3(coords, texture(depthtex0, coords).r) * 2.0 - 1.0;
    vec4 tmp = gbufferProjectionInverse * vec4(clipPos, 1.0);
    return tmp.xyz / tmp.w;
}

int getBlockId(vec2 coords) {
    return int(texture(colortex1, coords).w * 255.0 + 0.5);
}

bool isHand(float depth) {
    return linearizeDepth(depth) < 0.56;
}

bool isSky(vec2 coords) {
    return texture(depthtex0, coords).r == 1.0;
}

/*------------------ LIGHTMAP ------------------*/
const float rainAmbientDarkness = 0.8;

float getSkyLightmap(vec2 coords) {
    float lightmap = texture(colortex2, coords).w;
    return saturate((lightmap * lightmap) * 2.0 - 1.0);
}

vec3 getLightmapColor(vec2 lightMap, vec3 dayTimeColor) {
    lightMap.x = TORCHLIGHT_MULTIPLIER * pow(lightMap.x, 5.06);

    vec3 torchLight = lightMap.x * TORCH_COLOR;
    vec3 skyLight = (lightMap.y * lightMap.y) * dayTimeColor;
    return torchLight + max(vec3(EPS), skyLight - clamp(rainStrength, 0.0, rainAmbientDarkness));
}

/*------------------ WORLD TIME & SKY ------------------*/
float wTime = float(worldTime);
float timeSunrise  = ((clamp(wTime, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(wTime, 0.0, 2000.0) / 2000.0));
float timeNoon     = ((clamp(wTime, 0.0, 2000.0)) / 2000.0) - ((clamp(wTime, 10000.0, 12000.0) - 10000.0) / 2000.0);
float timeSunset   = ((clamp(wTime, 10000.0, 12000.0) - 10000.0) / 2000.0) - ((clamp(wTime, 12500.0, 12750.0) - 12500.0) / 250.0);
float timeMidnight = ((clamp(wTime, 12500.0, 12750.0) - 12500.0) / 250.0) - ((clamp(wTime, 23000.0, 24000.0) - 23000.0) / 1000.0);
 
// Originally written by Capt Tatsu#7124
// Modified by Belmu#4066
float drawStars(vec3 viewPos) {
	vec3 worldPos = mat3(gbufferModelViewInverse) * viewPos;
	vec3 planeCoords = worldPos / (worldPos.y + length(worldPos.xz));
	vec2 coord = planeCoords.xz * 0.7 + cameraPosition.xz * 1e-4 + frameTime * 0.00125;
	coord = floor(coord * 1024.0) / 1024.0;

	float VdotU = saturate(dot(normalize(viewPos), normalize(upPosition)));
	float multiplier = sqrt(sqrt(VdotU)) * (1.0 - rainStrength);

	float star = 1.0;
	if(VdotU > 0.0) {
		star *= rand(coord.xy);
		star *= rand(-coord.xy + 0.1);
	}
	return (saturate(star - 0.83) * multiplier) * 2.0;
}

vec3 getDayColor() {
    const vec3 ambient_sunrise  = vec3(0.943, 0.572, 0.397);
    const vec3 ambient_noon     = vec3(1.000, 1.000, 0.930);
    const vec3 ambient_sunset   = vec3(0.943, 0.472, 0.297);
    const vec3 ambient_midnight = vec3(0.058, 0.054, 0.101);

    return ambient_sunrise * timeSunrise + ambient_noon * timeNoon + ambient_sunset * timeSunset + ambient_midnight * timeMidnight;
}

vec3 getDayTimeSkyGradient(in vec3 pos, vec3 viewPos) {  // Bottom Color -> Top Color
	pos.y += 0.2;
    vec3 skyGradient_sunrise  = mix(vec3(0.395, 0.435, 0.471), vec3(0.245, 0.305, 0.371), pos.y);
    vec3 skyGradient_noon     = mix(vec3(0.445, 0.575, 0.771), vec3(0.180, 0.225, 0.339), pos.y);
    vec3 skyGradient_sunset   = mix(vec3(0.395, 0.435, 0.471), vec3(0.245, 0.305, 0.371), pos.y);
    vec3 skyGradient_midnight = mix(vec3(0.058, 0.062, 0.088), vec3(0.000, 0.004, 0.025), pos.y) + drawStars(viewPos);

    return skyGradient_sunrise * timeSunrise + skyGradient_noon * timeNoon + skyGradient_sunset * timeSunset + skyGradient_midnight * timeMidnight;
}

vec3 viewPosSkyColor(vec3 viewPos) {
    return getDayTimeSkyGradient(normalize(mat3(gbufferModelViewInverse) * viewPos), viewPos);
}
