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

vec3 getMetalF0(float F0, vec3 albedo) {
    int metalID = int(F0 * 255.0 - 229.5);
    return metalID >= 0 && metalID < 8 ? HARDCODED_F0[metalID] : mix(vec3(F0), albedo, float(F0 * 255.0 > 229.5));
}

struct material {
    float F0;
    float rough;
    float ao;
    float emission;
    float subsurface;
    bool isMetal;

    vec3 albedo;
    float alpha;
    vec3 normal;

    int blockId;
    vec2 lightmap;
};

material getMaterial(vec2 coords) {
    uvec4 tex1     = texture(colortex1, coords);
    vec4 unpacked0 = unpackUnorm4x8(tex1.x);
    vec4 unpacked1 = unpackUnorm4x8(tex1.y);

    material mat;

    mat.rough      = unpacked0.x;
    mat.ao         = unpacked1.x;
    mat.emission   = unpacked1.y;
    mat.F0         = unpacked1.z;
    mat.subsurface = unpacked1.w;
    mat.isMetal    = mat.F0 * 255.0 > 229.5;

    mat.albedo = vec3((tex1.z >> 24u) & 255u, (tex1.z >> 16u) & 255u, (tex1.z >> 8u) & 255u) / 255.0;
    mat.alpha  = tex1.w;
    mat.normal = normalize(mat3(gbufferModelView) * decodeUnitVector(vec2((tex1.z & 255u), tex1.w) / 255.0));

    mat.blockId  = int(unpacked0.y * 255.0 + 0.5);
    mat.lightmap = unpacked0.zw;

    mat.albedo = RGBtoLinear(mat.albedo);

    return mat;
}

material getMaterialTranslucents(vec2 coords) {
    uvec4 tex2     = texture(colortex2, coords);
    vec4 unpacked0 = unpackUnorm4x8(tex2.x);
    vec4 unpacked1 = unpackUnorm4x8(tex2.y);

    material mat;

    mat.rough      = unpacked0.x;
    mat.ao         = unpacked1.x;
    mat.emission   = 0.0;
    mat.F0         = unpacked1.z;
    mat.subsurface = unpacked1.w;
    mat.isMetal    = mat.F0 * 255.0 > 229.5;

    mat.albedo = vec3((tex2.z >> 24u) & 255u, (tex2.z >> 16u) & 255u, (tex2.z >> 8u) & 255u) / 255.0;
    mat.alpha  = unpacked1.y;
    mat.normal = normalize(mat3(gbufferModelView) * decodeUnitVector(vec2((tex2.z & 255u), tex2.w) / 255.0));

    mat.blockId  = int(unpacked0.y * 255.0 + 0.5);
    mat.lightmap = unpacked0.zw;

    mat.albedo = RGBtoLinear(mat.albedo);

    return mat;
}

float getSkyLightmap(material mat) {
    return quintic(0.90, 0.96, mat.lightmap.y);
}
