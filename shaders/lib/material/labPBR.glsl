/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

struct material {
    vec3 albedo;
    float alpha;
    vec2 lightmap;
    vec3 normal;

    float roughness;
    float F0;
};

material getMaterial(vec4 tex0, vec4 tex1, vec4 tex2) {
    material data;

    data.albedo = tex0.xyz;
    data.alpha = tex0.w;
    data.lightmap = tex2.zw;
    data.normal = tex1.xyz * 2.0 - 1.0; // In 0-1 range, gbuffers can't store negative numbers.

    data.roughness = tex2.x;
    data.F0 = tex2.y;

    return data;
}