/*
  Author: Belmu (https://github.com/BelmuTM/)
  */

vec4 simpleReflections(vec4 color, vec3 viewPos, vec3 normal, float reflectivity) {
    vec3 reflected = reflect(normalize(viewPos), normal);
    vec3 hitPos = vec3(0.0f);

    if(isHand(texture2D(depthtex0, TexCoords).r)) return color;

    bool intersect = RayTraceSSR(viewPos, reflected, hitPos);
    if(!intersect) return color;

    vec4 hitColor = texture2D(colortex0, hitPos.xy);
    return mix(color, hitColor, reflectivity);
}
