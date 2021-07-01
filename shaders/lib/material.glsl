/***********************************************/
/*       Copyright (C) Noble SSRT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

struct material {
    vec3 albedo;
    float alpha;
    vec2 lightmap;
    vec3 normal;

    float ao;
    float roughness;
    float F0;
    float porosity;
    float scattering;
    float emission;
};

material getMaterial(vec4 tex0, vec4 tex1, vec4 tex2, vec4 tex3) {
    material data;

    data.albedo = tex0.xyz;
    data.alpha = tex0.w;
    data.lightmap = tex2.zw;
    data.normal = tex1.xyz * 2.0 - 1.0; // In 0-1 range, gbuffers can't store negative numbers.

    data.ao = tex1.w;
    data.roughness = tex2.x;
    data.F0 = tex2.y;
    data.porosity = tex3.y;
    data.scattering = tex3.z;
    data.emission = tex3.w;

    return data;
}