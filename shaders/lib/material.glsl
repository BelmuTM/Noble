/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

// Hardcoded values provided by Bálint#1673
const vec3 HARDCODED_F0[] = vec3[](
    vec3(0.53123, 0.51236, 0.49583), // Iron
    vec3(0.94423, 0.77610, 0.37340), // Gold
    vec3(0.91230, 0.91385, 0.91968), // Aluminium
    vec3(0.55560, 0.55454, 0.55478), // Chrome
    vec3(0.92595, 0.72090, 0.50415), // Copper
    vec3(0.63248, 0.62594, 0.64148), // Lead
    vec3(0.67885, 0.64240, 0.58841), // Platinum
    vec3(0.96200, 0.94947, 0.92212)  // Silver
);

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