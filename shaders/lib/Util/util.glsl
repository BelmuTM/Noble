/*
  Author: Belmu (https://github.com/BelmuTM/)
  */

vec3 getViewPos() {
    vec3 screenPos = vec3(TexCoords, texture2D(depthtex0, TexCoords).r);
    vec3 clipPos = screenPos * 2.0f - 1.0f;
    vec4 tmp = gbufferProjectionInverse * vec4(clipPos, 1.0f);
    return tmp.xyz / tmp.w;
}

bool isHandOrEntity() {
    return texture2D(colortex4, TexCoords).r != 0.0f;
}

int getBlockId() {
    return int(texture2D(colortex3, TexCoords).r * 255.0f + 0.5f);
}

bool isReflective() {
    return getBlockId() >= 1 && getBlockId() < 4;
}

bool isSpecular() {
    return getBlockId() >= 1 && getBlockId() < 4;
}

bool isHand(float depth) {
    depth = linearizeDepth(depth);
    return depth < 0.56f;
}

