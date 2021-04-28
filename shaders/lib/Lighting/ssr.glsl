/*
  Author: Belmu (https://github.com/BelmuTM/)
  */

vec4 simpleReflections(vec4 color, vec3 viewPos, vec3 normal, float metallic) {
    vec3 reflected = reflect(normalize(viewPos), normal);
    vec3 hitPos = vec3(0.0f);

    bool intersect = SSRT(viewPos, reflected, hitPos);
    vec2 coord = viewToScreen(hitPos).xy;
    vec4 hitColor = texture2D(colortex0, coord);

    if(texture2D(depthtex0, coord).r < 0.56) return color;

    vec4 result = mix(color, hitColor, metallic);
    // result.rgb *= (1.0f - pow(coord.x, 100.0f)) * (1.0f - pow(coord.y, 100.0f));

    return intersect ? result : color;
}
