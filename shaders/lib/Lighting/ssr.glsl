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

// https://www.unrealengine.com/en-US/blog/physically-based-shading-on-mobile?sessionInvalidated=true
vec4 EnvBRDFApprox(vec4 specular, float NdotV, float roughness) {
    const vec4 c0 = vec4(-1.0, -0.0275, -0.572, 0.022);
    const vec4 c1 = vec4(1.0, 0.0425, 1.04, -0.04);
    vec4 r = roughness * c0 + c1;
    float a004 = min(r.x * r.x, pow(1.0 - NdotV, 5.0)) * r.x + r.y;
    vec2 AB = vec2(-1.04, 1.04) * a004 + r.zw;
    return specular * AB.x + AB.y;
}

vec4 simpleReflections(vec4 color, vec3 viewPos, vec3 normal, float NdotV, float F0, float roughness) {
    viewPos += normal * 0.01;
    vec3 reflected = reflect(normalize(viewPos), normal);
    vec2 hitPos = vec2(0.0);
    bool intersect = raytrace(viewPos, reflected, 160, hitPos);

    if(!intersect) return color;
    if(isHand(texture2D(depthtex0, hitPos).r)) return color;

    float fresnel = F0 + (1.0 - F0) * pow(1.0 - NdotV, 5.0);
    vec4 hitColor = texture2D(colortex0, hitPos);
    return mix(color, hitColor, fresnel * getAttenuation(hitPos, 5.5));
}

/*
vec4 simpleRefraction(vec4 color, vec3 viewPos, vec3 normal, float NdotV, float F0) {

    float eta = 1.0 / 1.333;
    vec3 refracted = refract(normalize(viewPos), normal, eta);
    vec2 hitPos = vec2(0.0);
    bool intersect = raytrace(viewPos, refracted, 60, hitPos);

    if(!intersect) return color;
    if(isHand(texture2D(depthtex0, hitPos).r)) return color;

    float fresnel = F0 + (1.0 - F0) * pow(1.0 - NdotV, 5.0);
    vec4 hitColor = texture2D(colortex0, hitPos);
    return hitColor;
}
*/
