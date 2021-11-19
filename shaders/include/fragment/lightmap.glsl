/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

float getSkyLightmap(vec2 coords) {
    float lightmap = texture(colortex2, coords).w;
    return smoothstep(0.90, 0.96, lightmap); // Concept from Eldeston#3590
}

vec3 getLightmapColor(vec2 lightMap, vec3 skyIlluminance) {
    lightMap.x = TORCHLIGHT_MULTIPLIER * pow(lightMap.x, TORCHLIGHT_EXPONENT);
    vec3 blockLight = TORCH_COLOR * lightMap.x;
    vec3 skyLight   = skyIlluminance * (lightMap.y - clamp(rainStrength, 0.0, rainAmbientDarkness));
    return blockLight + skyLight;
}

vec4 sun(vec3 viewDir, vec3 lightDir) {
    float VdotL = maxEps(dot(viewDir, lightDir));
    float angle = quintic(0.9997, 0.99995, VdotL);
    return vec4(4.0) * angle;
}
