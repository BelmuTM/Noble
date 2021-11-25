/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

float wTime = float(worldTime);
float timeMidnight = ((clamp(wTime, 12500.0, 12750.0) - 12500.0) / 250.0) - ((clamp(wTime, 23000.0, 24000.0) - 23000.0) / 1000.0);

float getSkyLightmap(vec2 coords) {
    float lightmap = texture(colortex1, coords).w;
    return smoothstep(0.90, 0.96, lightmap); // Concept from Eldeston#3590
}

vec3 getBlockLight(vec2 lightmap) {
    return blackbody(BLOCKLIGHT_TEMPERATURE) * (BLOCKLIGHT_MULTIPLIER * pow(lightmap.x, BLOCKLIGHT_EXPONENT));
}

vec3 sun(vec3 viewDir, vec3 lightDir) {
    float VdotL = maxEps(dot(viewDir, lightDir));
    float angle = quintic(0.9998, 0.99995, VdotL);
    return (SUN_ILLUMINANCE + (10.0 * timeMidnight)) * angle;
}
