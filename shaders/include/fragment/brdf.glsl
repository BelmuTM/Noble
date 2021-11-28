/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/include/material.glsl"

// http://graphicrants.blogspot.com/2013/08/specular-brdf-reference.html

float distributionBeckmann(float NdotH, in float alpha) {
    alpha *= alpha;
    float NdotH2 = NdotH * NdotH;
    return (1.0 / (PI * alpha * (NdotH2 * NdotH2))) * exp((NdotH2 - 1.0) / (alpha * NdotH2));
}

float distributionGGX(float NdotH, in float alpha) {
    alpha *= alpha;
    float denom = (NdotH * NdotH) * (alpha - 1.0) + 1.0;
    return alpha / (PI * denom * denom);
}

float geometrySchlickGGX(float cosTheta, float roughness) {
    float denom = cosTheta * (1.0 - roughness) + roughness;
    return cosTheta / denom;
}

float geometrySmith(float NdotV, float NdotL, float roughness) {
    float r = roughness + 1.0;
    roughness = (r * r) / 8.0;

    float ggxV = geometrySchlickGGX(NdotV, roughness);
    float ggxL = geometrySchlickGGX(NdotL, roughness);
    return ggxV * ggxL;
}

float geometryCookTorrance(float NdotH, float NdotV, float VdotH, float NdotL) {
    float NdotH2 = 2.0 * NdotH;
    float g1 = (NdotH2 * NdotV) / VdotH;
    float g2 = (NdotH2 * NdotL) / VdotH;
    return min(1.0, min(g1, g2));
}

float schlickGaussian(float cosTheta, float F0) {
    float sphericalGaussian = exp2(((-5.55473 * cosTheta) - 6.98316) * cosTheta);
    return sphericalGaussian * (1.0 - F0) + F0;
}

vec3 schlickGaussian(float cosTheta, vec3 F0) {
    float sphericalGaussian = exp2(((-5.55473 * cosTheta) - 6.98316) * cosTheta);
    return sphericalGaussian * (1.0 - F0) + F0;
}

float fresnelDielectric(float NdotV, float surfaceIOR) {
    float n1 = airIOR, n2 = surfaceIOR, eta = n1 / n2;
    float sinThetaT = eta * clamp01(1.0 - (NdotV * NdotV));
    float cosThetaT = 1.0 - (sinThetaT * sinThetaT);

    float sPolar = (n2 * NdotV - n1 * cosThetaT) / (n2 * NdotV + n1 * cosThetaT);
    float pPolar = (n2 * cosThetaT - n1 * NdotV) / (n2 * cosThetaT + n1 * NdotV);

    return clamp01((sPolar * sPolar + pPolar * pPolar) * 0.5);
}

// Provided by LVutner: more to read here: http://jcgt.org/published/0007/04/01/
// Modified by Belmu
vec3 sampleGGXVNDF(vec3 viewDir, vec2 seed, float alpha) {
	// Section 3.2: transforming the view direction to the hemisphere configuration
	viewDir = normalize(vec3(alpha * viewDir.xy, viewDir.z));

	// Section 4.1: orthonormal basis (with special case if cross product is zero)
	float lensq = dot(viewDir.yx, viewDir.yx);
	vec3 T1 = vec3(lensq > 0.0 ? vec2(-viewDir.y, viewDir.x) * inversesqrt(lensq) : vec2(1.0, 0.0), 0.0);
	vec3 T2 = cross(T1, viewDir);

	// Section 4.2: parameterization of the projected area
	float r = sqrt(seed.x);
    float phi = TAU * seed.y;
	float t1 = r * cos(phi);
    float tmp = clamp01(1.0 - t1 * t1);
	float t2 = mix(sqrt(tmp), r * sin(phi), 0.5 + 0.5 * viewDir.z);

	// Section 4.3: reprojection onto hemisphere
	vec3 Nh = t1 * T1 + t2 * T2 + sqrt(clamp01(tmp - t2 * t2)) * viewDir;

	// Section 3.4: transforming the normal back to the ellipsoid configuration
	return normalize(vec3(alpha * Nh.xy, Nh.z));	
}

// https://www.unrealengine.com/en-US/blog/physically-based-shading-on-mobile?sessionInvalidated=true
vec3 envBRDFApprox(vec3 F0, float NdotV, float roughness) {
    const vec4 c0 = vec4(-1.0, -0.0275, -0.572, 0.022);
    const vec4 c1 = vec4( 1.0,  0.0425,  1.04,  -0.04);
    vec4 r = roughness * c0 + c1;
    float a004 = min(r.x * r.x, exp2(-9.28 * NdotV)) * r.x + r.y;
    vec2 AB = vec2(-1.04, 1.04) * a004 + r.zw;
    return F0 * AB.x + AB.y;
}

vec3 specularFresnel(float cosTheta, float F0, vec3 metalColor, bool isMetal) {
    return isMetal ? schlickGaussian(cosTheta, metalColor) : vec3(fresnelDielectric(cosTheta, F0toIOR(F0)));
}

vec3 cookTorranceSpecular(vec3 N, vec3 V, vec3 L, material mat) {
    vec3 H = normalize(V + L);
    float NdotV = maxEps(dot(N, V));
    float NdotL = maxEps(dot(N, L));
    float HdotL = maxEps(dot(H, L));
    float NdotH = maxEps(dot(N, H));

    float D = distributionGGX(NdotH, pow2(mat.rough));
    vec3 F  = specularFresnel(HdotL, mat.F0, getSpecularColor(mat.F0, mat.albedo), mat.isMetal);
    float G = geometrySmith(NdotV, NdotL, mat.rough);
        
    return clamp01((D * F * G) / (4.0 * NdotL * NdotV));
}

// OREN-NAYAR MODEL - QUALITATIVE 
// http://www1.cs.columbia.edu/CAVE/publications/pdfs/Oren_CVPR93.pdf
vec3 orenNayarDiffuse(vec3 N, vec3 V, vec3 L, float NdotL, float NdotV, float alpha, vec3 albedo) {
    vec2 angles = acos(vec2(NdotL, NdotV));
    if(angles.x < angles.y) angles = angles.yx;
    float cosA = clamp01(dot(normalize(V - NdotV * N), normalize(L - NdotL * N)));

    vec3 A = albedo * (INV_PI - 0.09 * (alpha / (alpha + 0.4)));
    vec3 B = albedo * (0.125 * (alpha /  (alpha + 0.18)));
    return A + B * max0(cosA) * sin(angles.x) * tan(angles.y);
}

// HAMMON DIFFUSE
// https://ubm-twvideo01.s3.amazonaws.com/o1/vault/gdc2017/Presentations/Hammon_Earl_PBR_Diffuse_Lighting.pdf
vec3 hammonDiffuse(vec3 N, vec3 V, vec3 L, material mat) {
    float alpha = pow2(mat.rough);

    vec3 H = normalize(V + L);
    float VdotL = maxEps(dot(V, L));
    float NdotH = maxEps(dot(N, H));
    float NdotV = maxEps(dot(N, V));
    float NdotL = maxEps(dot(N, L));

    // Concept of replacing smooth surface by Lambertian with energy conservation from LVutner#5199
    float energyConservationFactor = 1.0 - (4.0 * sqrt(mat.F0) + 5.0 * mat.F0 * mat.F0) * (1.0 / 9.0);
    float fresnelNL = 1.0 - schlickGaussian(NdotL, mat.F0);
    float fresnelNV = 1.0 - schlickGaussian(NdotV, mat.F0);

    float facing     = 0.5 + 0.5 * VdotL;
    float roughSurf  = facing * (0.9 - 0.4 * facing) * (0.5 + NdotH / NdotH);
    float smoothSurf = (fresnelNL * fresnelNV) / energyConservationFactor;

    float single = mix(smoothSurf, roughSurf, alpha) * INV_PI;
    float multi  = 0.1159 * alpha;

    return mat.albedo * (single + mat.albedo * multi);
}

/* UNPHYSICALLY BASED STUFF */
float getSkyLightmap(vec2 coords) {
    float lightmap = texture(colortex1, coords).w;
    return smoothstep(0.90, 0.96, lightmap); // Concept from Eldeston#3590
}

vec3 getBlockLight(vec2 lightmap) {
    return blackbody(BLOCKLIGHT_TEMPERATURE) * (BLOCKLIGHT_MULTIPLIER * pow(lightmap.x, BLOCKLIGHT_EXPONENT));
}

// Thanks LVutner and Jessie for the help!
// https://github.com/LVutner
// https://github.com/Jessie-LC
vec3 cookTorrance(vec3 V, vec3 N, vec3 L, material mat, vec3 shadows, vec3 celestialIlluminance, vec3 skyIlluminance) {
    V = -normalize(V);
    float NdotL = maxEps(dot(N, L));

    vec3 specular = SPECULAR == 0 ? vec3(0.0) : cookTorranceSpecular(N, V, L, mat);
    vec3 diffuse  = mat.isMetal   ? vec3(0.0) : hammonDiffuse(N, V, L, mat);

    vec2 lightmap   = texture(colortex1, texCoords).zw;
    vec3 skyLight   = skyIlluminance * ((lightmap.y * lightmap.y) - clamp(rainStrength, 0.0, rainAmbientDarkness));
    vec3 blockLight = getBlockLight(lightmap);

    vec3 lighting = vec3(0.0);
    /* DIRECT ->   */ lighting += ((diffuse + specular) * NdotL * shadows) * celestialIlluminance;
    /* INDIRECT -> */ lighting += (mat.isMetal ? vec3(0.0) : (mat.emission + blockLight + skyLight) * mat.albedo) * mat.ao;
    return lighting;
}
