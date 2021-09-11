/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec3 getViewPos(vec2 coords) {
    vec3 clipPos = vec3(coords, texture2D(depthtex0, coords).r) * 2.0 - 1.0;
    vec4 tmp = gbufferProjectionInverse * vec4(clipPos, 1.0);
    return tmp.xyz / tmp.w;
}

int getBlockId(vec2 coords) {
    return int(texture2D(colortex1, coords).w * 255.0 + 0.5);
}

bool isHand(float depth) {
    return linearizeDepth(depth) < 0.56;
}

bool isSky(vec2 coords) {
    return texture2D(depthtex0, coords).r == 1.0;
}

/*------------------ LIGHTMAP ------------------*/
const float rainAmbientDarkness = 0.8;

float getSkyLightmap(vec2 coords) {
    float lightmap = texture2D(colortex2, coords).w;
    return clamp((lightmap * lightmap) * 2.0 - 1.0, 0.0, 1.0);
}

vec3 getLightmapColor(vec2 lightMap, vec3 dayTimeColor) {
    lightMap.x = TORCHLIGHT_MULTIPLIER * pow(lightMap.x, 5.06);

    vec3 torchLight = lightMap.x * TORCH_COLOR;
    vec3 skyLight = (lightMap.y * lightMap.y) * dayTimeColor;
    return torchLight + max(vec3(EPS), skyLight - clamp(rainStrength, 0.0, rainAmbientDarkness));
}
