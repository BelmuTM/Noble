/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

// Written by n_r4h33m#7259
float getAttenuation(vec2 coords, float scale) {
    float borderDist = min(1.0f - max(coords.x, coords.y), min(coords.x, coords.y));
    float border = clamp(borderDist > scale ? 1.0f : borderDist / scale, 0.0f, 1.0f);
    return border;
}

vec4 simpleReflections(vec4 color, vec3 viewPos, vec3 normal, float reflectivity) {
    vec3 reflected = reflect(normalize(viewPos), normal);
    vec2 hitPos = vec2(0.0f);

    bool intersect = raytrace(viewPos, reflected, bayer64(TexCoords), hitPos);
    if(!intersect) return color;

    if(isHand(texture2D(depthtex0, hitPos).r)) return color;

    vec4 hitColor = texture2D(colortex0, hitPos);
    return mix(color, hitColor, reflectivity * getAttenuation(hitPos, 3.25f));
}
