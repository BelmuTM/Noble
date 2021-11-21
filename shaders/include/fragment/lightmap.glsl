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

vec3 getBlockLight(vec2 lightmap) {
    return TORCH_COLOR * (TORCHLIGHT_MULTIPLIER * pow(lightmap.x, TORCHLIGHT_EXPONENT));
}

vec4 sun(vec3 viewDir, vec3 lightDir) {
    float VdotL = maxEps(dot(viewDir, lightDir));
    float angle = quintic(0.9997, 0.99995, VdotL);
    return vec4(4.0) * angle;
}