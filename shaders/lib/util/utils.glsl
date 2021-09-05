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

bool isSky() {
    return texture2D(depthtex0, texCoords).r == 1.0;
}

float getSkyLightmap() {
    float lightmap = texture2D(colortex2, texCoords).w;
    return clamp((lightmap * lightmap) * 2.0 - 1.0, 0.0, 1.0);
}
