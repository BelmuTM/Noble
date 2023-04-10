/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

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

    int blockId;
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

float gerstnerWaves(vec2 coords, float time, float steepness, float amplitude, float lambda, vec2 direction) {
    const float g = 9.81; // Earth's gravity constant

	float k = TAU / lambda;
    float x = (sqrt(g * k)) * time - k * dot(direction, coords);

    return amplitude * pow(sin(x) * 0.5 + 0.5, steepness);
}

float calculateWaveHeight(vec2 position, int octaves) {
    float height = 0.0;

    float time      = RENDER_MODE == 0 ? frameTimeCounter : 1.0;
    float steepness = WAVE_STEEPNESS;
    float amplitude = WAVE_AMPLITUDE;
    float lambda    = WAVE_LENGTH;

    const float angle   = TAU * 0.4;
	const mat2 rotation = mat2(cos(angle), -sin(angle), sin(angle), cos(angle));

    vec2 direction = vec2(0.786, 0.352);

    for(int i = 0; i < octaves; i++) {
        height -= gerstnerWaves(position + (FBM(position, 2, 0.3) * 2.0 - 1.0) * pow(lambda, 0.333), time, steepness, amplitude, lambda, direction);

        steepness *= 1.1;
        amplitude *= 0.6;
        lambda    *= 0.6;
        direction *= rotation;
    }
    return height;
}

const vec2[2] offset = vec2[2](vec2(0.5, 0.0), vec2(0.0, 0.5));

vec3 getWaterNormals(vec3 worldPos, int octaves) {
    vec2 position = worldPos.xz;

    float pos0 = calculateWaveHeight(position,             octaves);
	float pos1 = calculateWaveHeight(position + offset[0], octaves);
	float pos2 = calculateWaveHeight(position + offset[1], octaves);

    return vec3(pos0 - pos1, pos0 - pos2, 1.0);
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
	float a = (ior - 1.0) / (ior + 1.0);
	return a * a;
}

mat2x3 getHardcodedMetal(Material material) {
    int metalID = int(material.F0 * 255.0 - 229.5);
    return metalID >= 0 && metalID < 8 ? hardcodedMetals[metalID] : mat2x3(f0ToIOR(material.albedo), vec3(0.0));
}

Material getMaterial(vec2 coords) {
    coords       *= viewSize;
    uvec4 dataTex = texelFetch(colortex1, ivec2(coords), 0);

    Material material;
    material.roughness  = ((dataTex.z >> 24u) & 255u) * rcpMaxVal8;
    material.roughness *= material.roughness;
    material.ao         = (dataTex.y & 255u)          * rcpMaxVal8;
    material.emission   = ((dataTex.y >> 8u)  & 255u) * rcpMaxVal8;
    material.F0         = ((dataTex.y >> 16u) & 255u) * rcpMaxVal8;
    material.subsurface = ((dataTex.y >> 24u) & 255u) * rcpMaxVal8;

    #if MATERIAL_AO == 0
        material.ao = 1.0;
    #endif

    material.albedo.r = (dataTex.z          & 255u) * rcpMaxVal8;
	material.albedo.g = ((dataTex.z >> 8u)  & 255u) * rcpMaxVal8;
	material.albedo.b = ((dataTex.z >> 16u) & 255u) * rcpMaxVal8;

    #if TONEMAP == ACES
        material.albedo = srgbToAP1Albedo(material.albedo);
    #else
        material.albedo = srgbToLinear(material.albedo);
    #endif

    if(material.F0 * maxVal8 > 229.5) {
        mat2x3 hcm = getHardcodedMetal(material);
        material.N = hcm[0], material.K = hcm[1];
    } else {
        material.N = vec3(f0ToIOR(material.F0));
        material.K = vec3(0.0);
    }

    material.parallaxSelfShadowing = dataTex.x & 1u;

    material.normal = mat3(gbufferModelView) * decodeUnitVector(vec2(dataTex.w & 65535u, (dataTex.w >> 16u) & 65535u) * rcpMaxVal16);

    material.blockId  = int((dataTex.x >> 26u) & 63u);
    material.lightmap = vec2((dataTex.x >> 1u) & 8191u, (dataTex.x >> 14u) & 4095u) * vec2(rcpMaxVal13, rcpMaxVal12);

    material.depth0 = texelFetch(depthtex0, ivec2(coords), 0).r;
    material.depth1 = texelFetch(depthtex1, ivec2(coords), 0).r;

    return material;
}

vec3 getBlockLightColor(Material material) {
    switch(material.blockId) {
        case 5: return blackbody(1573.0) * EMISSIVE_INTENSITY; // Lava, magma
        case 6: return blackbody(1900.0) * EMISSIVE_INTENSITY; // Flames, fire

        default: return blackbody(BLOCKLIGHT_TEMPERATURE) * EMISSIVE_INTENSITY;
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
