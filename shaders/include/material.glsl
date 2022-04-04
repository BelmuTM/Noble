/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

struct Material {
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

    float depth0;
    float depth1;
};

Material getMaterial(vec2 coords) {
    coords         *= viewSize;
    uvec4 dataTex   = texelFetch(colortex1, ivec2(coords), 0);
    mat2x4 unpacked = mat2x4(unpackUnorm4x8(dataTex.x), unpackUnorm4x8(dataTex.y));

    Material mat;
    mat.rough      = unpacked[0].x;
    mat.ao         = unpacked[1].x;
    mat.emission   = unpacked[1].y;
    mat.F0         = unpacked[1].z;
    mat.subsurface = unpacked[1].w;
    mat.isMetal    = mat.F0 * maxVal8 > 229.5;

    mat.albedo = vec3((dataTex.z >> 16u) & 255u, (dataTex.z >> 8u) & 255u, dataTex.z & 255u) / maxVal8;
    mat.normal = mat3(gbufferModelView) * decodeUnitVector(vec2((dataTex.w >> 16u) & 65535u, dataTex.w & 65535u) / maxVal16);

    mat.blockId  = int(unpacked[0].y * maxVal8 + 0.5);
    mat.lightmap = unpacked[0].zw;

    mat.depth0 = texelFetch(depthtex0, ivec2(coords), 0).r;
    mat.depth1 = texelFetch(depthtex1, ivec2(coords), 0).r;

    #if TONEMAP == 0
        mat.albedo = sRGBToAP1Albedo(mat.albedo);
    #else
        mat.albedo = sRGBToLinear(mat.albedo);
    #endif
    return mat;
}

const mat2x3 hardcodedMetals[] = mat2x3[](
    mat2x3(vec3(2.9114, 2.9497, 2.5845),    // Iron
           vec3(3.0893, 2.9318, 2.7670)),
    mat2x3(vec3(0.18299, 0.42108, 1.3734),  // Gold
           vec3(3.4242, 2.3459, 1.7704)),
    mat2x3(vec3(1.3456, 0.96521, 0.61722),  // Aluminum
           vec3(7.4746, 6.3995, 5.3031)),
    mat2x3(vec3(3.1071, 3.1812, 2.3230),    // Chrome
           vec3(3.3314, 3.3291, 3.1350)),
    mat2x3(vec3(0.27105, 0.67693, 1.3164),  // Copper
           vec3(3.6092, 2.6248, 2.2921)),
    mat2x3(vec3(1.9100, 1.8300, 1.4400),    // Lead
           vec3(3.5100, 3.4000, 3.1800)),
    mat2x3(vec3(2.3757, 2.0847, 1.8453),    // Platinum
           vec3(4.2655, 3.7153, 3.1365)),
    mat2x3(vec3(0.15943, 0.14512, 0.13547), // Silver
           vec3(3.9291, 3.1900, 2.3808))
);

mat2x3 getHardcodedMetal(Material mat) {
    int metalID = int(mat.F0 * maxVal8 - 229.5);
    return metalID >= 0 && metalID < 8 ? hardcodedMetals[metalID] : mat2x3(vec3(F0ToIOR(mat.albedo)), vec3(0.0));
}

vec3 getBlockLightIntensity(Material mat) {
    vec3 blockLightIntensity = vec3(0.0);

    switch(mat.blockId) {
        case 5: blockLightIntensity = blackbody(1573.0) * 300.0; break; // Lava, magma
        case 6: blockLightIntensity = blackbody(1900.0) * 500.0; break; // Flames, fire

        default:
        #if GI == 0
            blockLightIntensity = blackbody(BLOCKLIGHT_TEMPERATURE) * BLOCKLIGHT_INTENSITY;
        #else
            blockLightIntensity = mat.albedo * BLOCKLIGHT_INTENSITY;
        #endif
        break;
    }

    return blockLightIntensity;
}
