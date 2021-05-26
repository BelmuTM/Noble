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

material getMaterial(vec4 tex1, vec4 tex2, vec4 tex3) {
    material data;

    data.albedo = tex1.xyz;
    data.alpha = tex1.w;
    data.lightmap = tex3.zw;
    data.normal = tex2.xyz * 2.0 - 1.0; // In 0-1 range, gbuffers can't store negative numbers.

    data.roughness = tex3.x;
    data.F0 = tex3.y;

    return data;
}