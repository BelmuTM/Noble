/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

vec3 getViewPos() {
    vec3 screenPos = vec3(TexCoords, texture2D(depthtex0, TexCoords).r);
    vec3 clipPos = screenPos * 2.0 - 1.0;
    vec4 tmp = gbufferProjectionInverse * vec4(clipPos, 1.0);
    return tmp.xyz / tmp.w;
}

bool isHandOrEntity() {
    return texture2D(colortex4, TexCoords).r != 0.0;
}

int getBlockId() {
    return int(texture2D(colortex3, TexCoords).r * 255.0 + 0.5);
}

bool isReflective() {
    return getBlockId() >= 1 && getBlockId() < 6;
}

bool isSpecular() {
    return getBlockId() >= 1 && getBlockId() < 6;
}

bool isHand(float depth) {
    depth = linearizeDepth(depth);
    return depth < 0.56;
}

