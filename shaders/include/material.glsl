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

    vec3 albedo;
    vec3 normal;

    int blockId;
    vec2 lightmap;

    float depth0;
    float depth1;
};

const float airIOR  = 1.00029;
const float waterF0 = 0.02;

Material getMaterial(vec2 coords) {
    coords       *= viewSize;
    uvec4 dataTex = texelFetch(colortex1, ivec2(coords), 0);
    vec4 unpacked = unpackUnorm4x8(dataTex.y);

    Material mat;
    mat.rough      = (dataTex.x & 255u)          * rcpMaxVal8;
    mat.ao         = (dataTex.y & 255u)          * rcpMaxVal8;
    mat.emission   = ((dataTex.y >> 8u)  & 255u) * rcpMaxVal8;
    mat.F0         = ((dataTex.y >> 16u) & 255u) * rcpMaxVal8;
    mat.subsurface = ((dataTex.y >> 24u) & 255u) * rcpMaxVal8;

    mat.albedo.r = (dataTex.z          & 2047u) * rcpMaxVal11;
	mat.albedo.g = ((dataTex.z >> 11u) & 1023u) * rcpMaxVal10;
	mat.albedo.b = ((dataTex.z >> 21u) & 2047u) * rcpMaxVal11;

    mat.normal = mat3(gbufferModelView) * decodeUnitVector(vec2(dataTex.w & 65535u, (dataTex.w >> 16u) & 65535u) * rcpMaxVal16);

    mat.blockId  = int((dataTex.x >> 26u) & 63u);
    mat.lightmap = vec2((dataTex.x >> 8u) & 511u, (dataTex.x >> 17u) & 511u) * rcpMaxVal9;

    mat.depth0 = texelFetch(depthtex0, ivec2(coords), 0).r;
    mat.depth1 = texelFetch(depthtex1, ivec2(coords), 0).r;

    #if MATERIAL_AO == 0
        mat.ao = 1.0;
    #endif

    #if TONEMAP == 0
        mat.albedo = srgbToAP1Albedo(mat.albedo);
    #else
        mat.albedo = srgbToLinear(mat.albedo);
    #endif
    return mat;
}

float f0ToIOR(float F0) {
	F0 = sqrt(F0) * 0.99999;
	return (1.0 + F0) / (1.0 - F0);
}

vec3 f0ToIOR(vec3 F0) {
	F0 = sqrt(F0) * 0.99999;
	return (1.0 + F0) / (1.0 - F0);
}

float iorToF0(float ior) {
	float a = (ior - airIOR) / (ior + airIOR);
	return a * a;
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
    return metalID >= 0 && metalID < 8 ? hardcodedMetals[metalID] : mat2x3(f0ToIOR(mat.albedo) * airIOR, vec3(0.0));
}

vec3 getBlockLightColor(Material mat) {
    switch(mat.blockId) {
        case 5: return blackbody(1573.0) * BLOCKLIGHT_INTENSITY; // Lava, magma
        case 6: return blackbody(1900.0) * BLOCKLIGHT_INTENSITY; // Flames, fire

        #if GI == 0
            default: return blackbody(BLOCKLIGHT_TEMPERATURE) * BLOCKLIGHT_INTENSITY;
        #else
            default: return mat.albedo * 20.0;
        #endif
    }
    return vec3(0.0);
}

float getBlockLightFalloff(float lightmapX) {
    // Square distance law, thanks to SixthSurge#3922 for the help!
    return linearStep(0.00390625, 1.0, 1.0 / pow2(16.0 - 15.0 * lightmapX));
}


float getSkyLightFalloff(float lightmapY) {
    // Taken from Zombye#7365 (Spectrum - https://github.com/zombye/spectrum)
    return lightmapY * exp(6.0 * (lightmapY - 1.0));
}
