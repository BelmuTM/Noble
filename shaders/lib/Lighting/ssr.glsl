/*
  Author: Belmu (https://github.com/BelmuTM/)
  */

vec4 simpleReflections(vec4 color, vec3 viewPos, vec3 normal, float reflectivity) {
    vec3 reflected = reflect(normalize(viewPos), normal);
    vec3 hitPos = vec3(0.0f);

    bool intersect = rayTrace2(viewPos, reflected, hitPos);
    vec4 hitColor = texture2D(colortex0, hitPos.xy);

    if(isHand(texture2D(depthtex0, TexCoords).r)) return color;

    vec4 result = mix(color, hitColor, reflectivity);
    return intersect ? result : color;
}
