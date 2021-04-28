/*
  Author: Belmu (https://github.com/BelmuTM/)
  */

vec3 rayTraceShadows(vec3 lightDir, vec3 viewPos, vec3 normal) {
    vec3 hitPos = vec3(0.0f);
    bool intersect = SSRT(viewPos, lightDir, hitPos);

    return intersect ? vec3(0.0f) : vec3(1.0f);
}
