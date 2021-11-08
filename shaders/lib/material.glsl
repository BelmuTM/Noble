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

vec3 getSpecularColor(float F0, vec3 albedo) {
    int metalID = int(F0 * 255.0 - 229.5);
    return metalID >= 0 && metalID < 8 ? HARDCODED_F0[metalID] : mix(vec3(F0), albedo, float(F0 * 255.0 > 229.5));
}

struct material {
    vec3 albedo;
    float alpha;
    vec3 normal;

    float rough;
    float F0;
    bool isMetal;
    float emission;
};

material getMaterial(vec2 coords) {
    vec4 tex0 = texture(colortex0, coords);
    vec4 tex1 = texture(colortex1, coords);
    vec4 tex2 = texture(colortex2, coords);

    material mat;

    mat.albedo = tex0.xyz;
    mat.alpha = tex0.w;
    mat.normal = normalize(decodeNormal(tex1.xy));

    mat.rough = tex2.x;
    mat.F0 = tex2.y;
    mat.isMetal = mat.F0 * 255.0 > 229.5;
    mat.emission = tex1.z;

    return mat;
}