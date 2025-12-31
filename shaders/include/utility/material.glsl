/********************************************************************************/
/*                                                                              */
/*    Noble Shaders                                                             */
/*    Copyright (C) 2026  Belmu                                                 */
/*                                                                              */
/*    This program is free software: you can redistribute it and/or modify      */
/*    it under the terms of the GNU General Public License as published by      */
/*    the Free Software Foundation, either version 3 of the License, or         */
/*    (at your option) any later version.                                       */
/*                                                                              */
/*    This program is distributed in the hope that it will be useful,           */
/*    but WITHOUT ANY WARRANTY; without even the implied warranty of            */
/*    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the             */
/*    GNU General Public License for more details.                              */
/*                                                                              */
/*    You should have received a copy of the GNU General Public License         */
/*    along with this program.  If not, see <https://www.gnu.org/licenses/>.    */
/*                                                                              */
/********************************************************************************/

/*
    [Credits]:
        sixthsurge - help with the blocklight falloff function (https://github.com/sixthsurge)
        Zombye     - skylight falloff function (https://github.com/zombye)
*/

const float labPBRMetals = 229.5;

const vec3 labPBRData0Range = vec3(1.0, 8191.0, 4095.0);

struct Material {
    float F0;
    float roughness;
    float ao;
    float emission;
    float subsurface;

    vec3 albedo;
    vec3 normal;

    vec3 N;
    vec3 K;

    float parallaxSelfShadowing;

    int id;
    vec2 lightmap;

    float depth0;
    float depth1;
};

const float airIOR  = 1.00029;
const float waterF0 = 0.02;

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

float f0ToIOR(float F0) {
    F0 = sqrt(F0) * 0.99999;
    return airIOR * ((1.0 + F0) / (1.0 - F0));
}

vec3 f0ToIOR(vec3 F0) {
    F0 = sqrt(F0) * 0.99999;
    return airIOR * ((1.0 + F0) / (1.0 - F0));
}

float iorToF0(float ior) {
    float a = (ior - airIOR) / (ior + airIOR);
    return a * a;
}

mat2x3 getHardcodedMetal(Material material) {
    int metalID = int(material.F0 * 255.0 - labPBRMetals);
    return metalID >= 0 && metalID < 8 ? hardcodedMetals[metalID] : mat2x3(f0ToIOR(material.albedo), vec3(0.0));
}

bool isWater(int materialID) {
    #if defined DISTANT_HORIZONS
        return materialID == WATER_ID || materialID == DH_BLOCK_WATER;
    #else
        return materialID == WATER_ID;
    #endif
}

Material getMaterial(vec2 coords) {
    coords *= viewSize;
    
    uvec4 dataTexture = texelFetch(GBUFFERS_DATA, ivec2(coords), 0);

    vec4 data1 = unpackUnorm4x8(dataTexture.y);
    vec4 data2 = unpackUnorm4x8(dataTexture.z);

    Material material;
    material.roughness  = data2.w * data2.w;
    material.ao         = data1.x;
    material.emission   = data1.y;
    material.F0         = data1.z;
    material.subsurface = data1.w;

    #if MATERIAL_AO == 0
        material.ao = 1.0;
    #endif

    material.albedo = data2.rgb;

    #if TONEMAP == ACES
        material.albedo = srgbToAP1Albedo(material.albedo);
    #else
        material.albedo = srgbToLinear(material.albedo);
    #endif

    if (material.F0 * maxFloat8 > labPBRMetals) {
        mat2x3 hcm = getHardcodedMetal(material);
        material.N = hcm[0], material.K = hcm[1];
    } else {
        material.N = vec3(f0ToIOR(material.F0));
        material.K = vec3(0.0);
    }

    material.parallaxSelfShadowing = float(dataTexture.x & 1u);

    material.normal = sceneToView(decodeUnitVector(unpackUnorm2x16(dataTexture.w)));

    material.id       = int(dataTexture.x >> 26u & 63u);
    material.lightmap = vec2(dataTexture.x >> 1u & 8191u, dataTexture.x >> 14u & 4095u) * vec2(rcpMaxFloat13, rcpMaxFloat12);

    material.depth0 = texelFetch(depthtex0, ivec2(coords), 0).r;
    material.depth1 = texelFetch(depthtex1, ivec2(coords), 0).r;

    #if defined CHUNK_LOADER_MOD_ENABLED
        if (material.depth0 >= 1.0) {
            material.depth0 = texelFetch(modDepthTex0, ivec2(coords), 0).r;
            material.depth1 = texelFetch(modDepthTex1, ivec2(coords), 0).r;
        }
    #endif

    return material;
}

vec3 getBlockLightColor(Material material) {
    return blackbody(BLOCKLIGHT_TEMPERATURE) * EMISSIVE_INTENSITY;
}

float getBlocklightFalloff(float lightmapX) {
    return linearStep(0.00390625, 1.0, 1.0 / pow2(16.0 - 15.0 * lightmapX));
}


float getSkylightFalloff(float lightmapY) {
    return lightmapY * exp(6.0 * (lightmapY - 1.0));
}
