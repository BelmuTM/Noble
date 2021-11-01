/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/lib/material.glsl"

// http://graphicrants.blogspot.com/2013/08/specular-brdf-reference.html

float D_Beckmann(float NdotH, in float alpha) {
    alpha *= alpha;
    float NdotH2 = NdotH * NdotH;
    return (1.0 / (PI * alpha * (NdotH2 * NdotH2))) * exp((NdotH2 - 1.0) / (alpha * NdotH2));
}

float D_GGX(float NdotH, in float alpha) {
    // GGXTR(N,H,α) = α² / π*((N*H)²*(α² + 1)-1)²
    alpha *= alpha;
    float denom = (NdotH * NdotH) * (alpha - 1.0) + 1.0;
    return alpha / (PI * denom * denom);
}

float G_SchlickGGX(float cosTheta, float roughness) {
    // SchlickGGX(N,V,k) = N*V/(N*V)*(1 - k) + k
    float denom = cosTheta * (1.0 - roughness) + roughness;
    return cosTheta / denom;
}

float G_Smith(float NdotV, float NdotL, float roughness) {
    float r = roughness + 1.0;
    roughness = (r * r) / 8.0;

    float ggxV = G_SchlickGGX(NdotV, roughness);
    float ggxL = G_SchlickGGX(NdotL, roughness);
    return ggxV * ggxL;
}

float G_CookTorrance(float NdotH, float NdotV, float VdotH, float NdotL) {
    float NdotH2 = 2.0 * NdotH;
    float g1 = (NdotH2 * NdotV) / VdotH;
    float g2 = (NdotH2 * NdotL) / VdotH;
    return min(1.0, min(g1, g2));
}

vec3 fresnelSchlick(float cosTheta, vec3 F0) {
    return F0 + (1.0 - F0) * pow5(1.0 - cosTheta);
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

vec3 cookTorranceFresnel(float cosTheta, float F0, vec3 metalColor, bool isMetal) {
    return isMetal ? schlickGaussian(cosTheta, metalColor) : vec3(fresnelDielectric(cosTheta, F0toIOR(F0)));
}

vec3 cookTorranceSpecular(vec3 N, vec3 V, vec3 L, float roughness, float F0, vec3 albedo, bool isMetal) {
    vec3 H = normalize(V + L);
    float NdotV = max(EPS, dot(N, V));
    float NdotL = max(EPS, dot(N, L));
    float HdotL = max(EPS, dot(H, L));
    float NdotH = max(EPS, dot(N, H));

    float D = D_GGX(NdotH, roughness * roughness);
    vec3 F = cookTorranceFresnel(HdotL, F0, getSpecularColor(F0, albedo), isMetal);
    float G = G_Smith(NdotV, NdotL, roughness);
        
    return clamp01((D * F * G) / max(EPS, 4.0 * NdotL * NdotV));
}

// OREN-NAYAR MODEL - QUALITATIVE 
// http://www1.cs.columbia.edu/CAVE/publications/pdfs/Oren_CVPR93.pdf
vec3 orenNayarDiffuse(vec3 N, vec3 V, vec3 L, float NdotL, float NdotV, float alpha, vec3 albedo) {
    vec2 angles = acos(vec2(NdotL, NdotV));
    if(angles.x < angles.y) angles = angles.yx;
    float cosA = clamp01(dot(normalize(V - NdotV * N), normalize(L - NdotL * N)));

    vec3 A = albedo * (INV_PI - 0.09 * (alpha / (alpha + 0.4)));
    vec3 B = albedo * (0.125 * (alpha /  (alpha + 0.18)));
    return A + B * max(0.0, cosA) * sin(angles.x) * tan(angles.y);
}

// HAMMON DIFFUSE
// https://ubm-twvideo01.s3.amazonaws.com/o1/vault/gdc2017/Presentations/Hammon_Earl_PBR_Diffuse_Lighting.pdf
vec3 hammonDiffuse(vec3 N, vec3 V, vec3 L, float alpha, vec3 albedo) {
    vec3 H = normalize(V + L);
    float LdotV = max(EPS, dot(L, V));
    float NdotH = max(EPS, dot(N, H));
    float NdotV = max(EPS, dot(N, V));
    float NdotL = max(EPS, dot(N, L));

    float facing     = 0.5 + 0.5 * LdotV;
    float roughSurf  = facing * (0.9 - 0.4 * facing) * (0.5 + NdotH / NdotH);
    float smoothSurf = 1.05 * (1.0 - pow5(1.0 - NdotL)) * (1.0 - pow5(1.0 - NdotV));

    float single = mix(smoothSurf, roughSurf, alpha) * INV_PI;
    float multi  = 0.1159 * alpha;

    return albedo * (single + albedo * multi);
}

// Thanks LVutner for the help!
// https://github.com/LVutner
vec3 cookTorrance(vec3 viewPos, vec3 N, vec3 L, material mat, vec3 lightmap, vec3 shadowmap, vec3 illuminance) {
    vec3 V = -normalize(viewPos);
    bool isMetal = mat.F0 * 255.0 > 229.5;
    float alpha = mat.roughness * mat.roughness;
    
    vec3 H = normalize(V + L);
    float HdotL = max(EPS, dot(H, L));
    float NdotV = max(EPS, dot(N, V));
    float NdotL = max(EPS, dot(N, L));

    vec3 specular = vec3(0.0);
    #if SPECULAR == 1
        specular = cookTorranceSpecular(N, V, L, mat.roughness, mat.F0, mat.albedo, isMetal);
    #endif

    vec3 diffuse = vec3(0.0);
    if(!isMetal) { 
        diffuse = hammonDiffuse(N, V, L, alpha, mat.albedo);

        /* Energy Conservation */
        float energyConservationFactor = 1.0 - (4.0 * sqrt(mat.F0) + 5.0 * mat.F0 * mat.F0) * 0.11111111;
        diffuse *= 1.0 - cookTorranceFresnel(NdotV, mat.F0, getSpecularColor(mat.F0, mat.albedo), isMetal);;
        diffuse /= energyConservationFactor;
    }

    /* Calculating Indirect / Direct Lighting */
    vec3 Lighting = (diffuse + specular) * (NdotL * shadowmap) * illuminance;

    if(!isMetal) {
        Lighting += mat.emission * mat.albedo;
        Lighting += AMBIENT * mat.albedo;
        Lighting *= lightmap;
    }
    return Lighting;
}
