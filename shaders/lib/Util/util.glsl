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

float getBlockId(sampler2D colortex) {
    return texture2D(colortex, TexCoords).r;
}

float luma(vec3 color) {
    return dot(color, vec3(0.299f, 0.587f, 0.114f));
}
