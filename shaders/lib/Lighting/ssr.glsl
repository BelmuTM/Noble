/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

// Written by n_r4h33m#7259
float getAttenuation(vec2 coords, float scale) {
    float borderDist = min(1.0 - max(coords.x, coords.y), min(coords.x, coords.y));
    float border = clamp(borderDist > scale ? 1.0 : borderDist / scale, 0.0, 1.0);
    return border;
}

vec4 simpleReflections(vec4 color, vec3 viewPos, vec3 normal, float LdotH, float F0) {
    /*
    float jitter = fract((texCoords.x + texCoords.y) * 0.5);
    float noise = hash12(texCoords);
    noise = fract(noise + (frameTime * 17.0));
    */

    vec3 reflected = reflect(normalize(viewPos), normal);
    vec2 hitPos = vec2(0.0);
    bool intersect = raytrace(viewPos, reflected, 160, hitPos);

    if(!intersect) return color;
    if(isHand(texture2D(depthtex0, hitPos).r)) return color;

    float fresnel = F0 + (1.0 - F0) * pow(1.0 - LdotH, 5.0);
    vec4 hitColor = texture2D(colortex0, hitPos);
    return mix(color, hitColor, fresnel) * getAttenuation(hitPos, 3.25);
}
