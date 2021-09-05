/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

struct material {
    vec3 albedo;
    float alpha;
    vec3 normal;

    float roughness;
    float F0;
    float emission;
};

material getMaterial(vec4 tex0, vec4 tex1, vec4 tex2) {
    material data;

    data.albedo = tex0.xyz;
    data.alpha = tex0.w;
    data.normal = decodeNormal(tex1.xy);

    data.roughness = tex2.x;
    data.F0 = tex2.y;
    data.emission = tex1.z;

    return data;
}