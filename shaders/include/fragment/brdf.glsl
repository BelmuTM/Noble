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
    float NdotH2 = pow2(NdotH);
    return (1.0 / (PI * alpha * pow2(NdotH2))) * exp((NdotH2 - 1.0) / (alpha * NdotH2));
}

float distributionGGX(float NdotH, in float alpha) {
    alpha *= alpha;
    float denom = (NdotH * alpha - NdotH) * NdotH + 1.0;
    return alpha / pow2(denom) * INV_PI;
}

float geometrySchlickGGX(float cosTheta, float roughness) {
    float denom = cosTheta * (1.0 - roughness) + roughness;
    return cosTheta / denom;
}

float G1SmithGGX(float NdotV, in float roughness) {
    roughness = pow4(roughness);
    return clamp01(2.0 * NdotV / (NdotV + sqrt(roughness + (NdotV - NdotV * roughness) * NdotV)));
}

float G2SmithGGX(float NdotV, float NdotL, in float roughness) {
	roughness = pow4(roughness);
	float g1  = NdotL * sqrt(roughness + (NdotV - NdotV * roughness) * NdotV);
	float g2  = NdotV * sqrt(roughness + (NdotL - NdotL * roughness) * NdotL);
	return clamp01((2.0 * NdotV * NdotL) / (g1 + g2));
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
    float n1 = airIOR, n2 = surfaceIOR;
    float sinThetaT = (n1 / n2) * max0(1.0 - pow2(NdotV));
    float cosThetaT = 1.0 - pow2(sinThetaT);

    if(sinThetaT >= 1.0) {
        return 1.0;
    } else {
        float sPolar = (n2 * NdotV - n1 * cosThetaT) / (n2 * NdotV + n1 * cosThetaT);
        float pPolar = (n2 * cosThetaT - n1 * NdotV) / (n2 * cosThetaT + n1 * NdotV);

        return clamp01((pow2(sPolar) + pow2(pPolar)) * 0.5);
    }
}

vec3 fresnelDielectric(float NdotV, vec3 surfaceIOR) {
    vec3 n1 = vec3(airIOR), n2 = surfaceIOR;
    vec3 sinThetaT = (n1 / n2) * max0(1.0 - pow2(NdotV));
    vec3 cosThetaT = 1.0 - pow2(sinThetaT);

    vec3 sPolar = (n2 * NdotV - n1 * cosThetaT) / (n2 * NdotV + n1 * cosThetaT);
    vec3 pPolar = (n2 * cosThetaT - n1 * NdotV) / (n2 * cosThetaT + n1 * NdotV);

    return clamp01((pow2(sPolar) + pow2(pPolar)) * 0.5);
}

// Provided by LVutner: more to read here: http://jcgt.org/published/0007/04/01/
// Modified by Belmu
vec3 sampleGGXVNDF(vec3 viewDir, vec2 seed, float alpha) {
	// Section 3.2: transforming the view direction to the hemisphere configuration
	viewDir = normalize(vec3(alpha * viewDir.xy, viewDir.z));

	// Section 4.1: orthonormal basis (with special case if cross product is zero)
	float lensq = dot(viewDir.yx, viewDir.yx);
	vec3 T1     = vec3(lensq > 0.0 ? vec2(-viewDir.y, viewDir.x) * inversesqrt(lensq) : vec2(1.0, 0.0), 0.0);
	vec3 T2     = cross(T1, viewDir);

	// Section 4.2: parameterization of the projected area
	float r   = sqrt(seed.x);
    float phi = TAU * seed.y;
	float t1  = r * cos(phi);
    float tmp = clamp01(1.0 - pow2(t1));
	float t2  = mix(sqrt(tmp), r * sin(phi), 0.5 + 0.5 * viewDir.z);

	// Section 4.3: reprojection onto hemisphere
	vec3 Nh = t1 * T1 + t2 * T2 + sqrt(clamp01(tmp - pow2(t2))) * viewDir;

	// Section 3.4: transforming the normal back to the ellipsoid configuration
	return normalize(vec3(alpha * Nh.xy, Nh.z));	
}

// https://www.unrealengine.com/en-US/blog/physically-based-shading-on-mobile?sessionInvalidated=true
vec3 envBRDFApprox(vec3 F0, float NdotV, float roughness) {
    const vec4 c0 = vec4(-1.0, -0.0275, -0.572, 0.022);
    const vec4 c1 = vec4( 1.0,  0.0425,  1.04,  -0.04);
    vec4 r        = roughness * c0 + c1;
    float a004    = min(r.x * r.x, exp2(-9.28 * NdotV)) * r.x + r.y;
    vec2 AB       = vec2(-1.04, 1.04) * a004 + r.zw;
    return F0 * AB.x + AB.y;
}

vec3 specularFresnel(float cosTheta, vec3 F0, bool isMetal) {
    return isMetal ? schlickGaussian(cosTheta, F0) : fresnelDielectric(cosTheta, F0toIOR(F0));
}

vec3 cookTorranceSpecular(vec3 N, vec3 V, vec3 L, material mat) {
    vec3 H = normalize(V + L);
    float NdotV = maxEps(dot(N, V));
    float NdotL = maxEps(dot(N, L));
    float HdotL = maxEps(dot(H, L));
    float NdotH = maxEps(dot(N, H));

    float D = distributionGGX(NdotH, pow2(mat.rough));
    vec3 F  = specularFresnel(HdotL, getSpecularColor(mat.F0, mat.albedo), mat.isMetal);
    float G = geometrySmith(NdotV, NdotL, mat.rough);
        
    return clamp01((D * F * G) / (4.0 * NdotL * NdotV));
}

// HAMMON DIFFUSE
// https://ubm-twvideo01.s3.amazonaws.com/o1/vault/gdc2017/Presentations/Hammon_Earl_PBR_Diffuse_Lighting.pdf
vec3 hammonDiffuse(vec3 N, vec3 V, vec3 L, material mat, bool pt) {
    float alpha = pow2(mat.rough);

    vec3 H = normalize(V + L);
    float VdotL = maxEps(dot(V, L));
    float NdotH = maxEps(dot(N, H));
    float NdotV = maxEps(dot(N, V));
    float NdotL = maxEps(dot(N, L));

    float facing     = 0.5 + 0.5 * VdotL;
    float roughSurf  = facing * (0.9 - 0.4 * facing) * (0.5 + NdotH / NdotH);

    // Concept of replacing smooth surface by Lambertian with energy conservation from LVutner#5199
    float smoothSurf;
    if(!pt) {
        float energyConservationFactor = 1.0 - (4.0 * sqrt(mat.F0) + 5.0 * mat.F0 * mat.F0) * (1.0 / 9.0);
        float fresnelNL = 1.0 - schlickGaussian(NdotL, mat.F0);
        float fresnelNV = 1.0 - schlickGaussian(NdotV, mat.F0);

        smoothSurf = (fresnelNL * fresnelNV) / energyConservationFactor;
    } else {
        smoothSurf = 1.05 * (1.0 - pow5(1.0 - NdotL)) * (1.0 - pow5(1.0 - NdotV));
    }
    float single = mix(smoothSurf, roughSurf, alpha) * INV_PI;
    float multi  = 0.1159 * alpha;

    return max0(mat.albedo * single + mat.albedo * multi);
}

// Disney SSS from: https://www.shadertoy.com/view/XdyyDd
float schlickWeight(float cosTheta) {
    return pow5(clamp01(1.0 - cosTheta));
}

float disneySubsurface(vec3 N, vec3 V, vec3 L, material mat) {
    vec3 H      = normalize(V + L);
    float NdotV = maxEps(dot(N, V));
    float NdotL = maxEps(dot(N, L));
    float LdotH = maxEps(dot(L, H));

    float FL    = schlickWeight(NdotL), FV = schlickWeight(NdotV);
    float Fss90 = LdotH * LdotH * mat.rough;
    float Fss   = mix(1.0, Fss90, FL) * mix(1.0, Fss90, FV);
    float ss    = 1.25 * (Fss * (1.0 / (NdotL + NdotV) - 0.5) + 0.5);

    return clamp01(ss);
}

// Thanks LVutner and Jessie for the help!
// https://github.com/LVutner
// https://github.com/Jessie-LC
vec3 cookTorrance(vec3 V, vec3 N, vec3 L, material mat, vec3 shadows, vec3 shadowLightIlluminance, vec3 skyIlluminance, float ambientOcclusion) {
    V = -normalize(V);

    float SSS     = disneySubsurface(N, V, L, mat);
    vec3 specular = SPECULAR == 0 ? vec3(0.0) : cookTorranceSpecular(N, V, L, mat);
    vec3 diffuse  = mat.isMetal   ? vec3(0.0) : mix(hammonDiffuse(N, V, L, mat, false), SSS * mat.albedo, mat.subsurface);

    vec2 lightmap = texture(colortex1, texCoords).zw;
    lightmap.x    = BLOCKLIGHTMAP_MULTIPLIER * pow(clamp01(lightmap.x), BLOCKLIGHTMAP_EXPONENT);
    lightmap.y    = pow2(clamp01(lightmap.y));

    vec3 skyLight   = skyIlluminance * lightmap.y;
    vec3 blockLight = blackbody(BLOCKLIGHT_TEMPERATURE) * lightmap.x * BLOCKLIGHT_MULTIPLIER;

    vec3 direct   = (diffuse + specular) * (shadows * maxEps(dot(N, L))) * shadowLightIlluminance;
    vec3 indirect = mat.isMetal ? vec3(0.0) : mat.albedo * (mat.emission + blockLight + skyLight) * mat.ao * ambientOcclusion;

    return direct + indirect;
}
