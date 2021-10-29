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
const float rainAmbientDarkness = 0.3;

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
    float VdotL = max(EPS, dot(viewDir, lightDir));
    float angle = quintic(0.9997, 0.99995, VdotL);
    return vec4(4.0) * angle;
}
