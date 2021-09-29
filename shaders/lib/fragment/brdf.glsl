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
    float denom = ((NdotH * NdotH) * (alpha - 1.0) + 1.0);
    return alpha / (PI * denom * denom);
}

float G_SchlickBeckmann(float cosTheta, float roughness) {
    // SchlickGGX(N,V,k) = N*V/(N*V)*(1 - k) + k
    float denom = cosTheta * (1.0 - roughness) + roughness;
    return cosTheta / denom;
}

float G_Smith(float NdotV, float NdotL, float roughness) {
    float r = roughness + 1.0;
    roughness = (r * r) / 8.0;

    float ggxV = G_SchlickBeckmann(NdotV, roughness);
    float ggxL = G_SchlickBeckmann(NdotL, roughness);
    return ggxV * ggxL;
}

float G_GGX(float NdotV, float alpha) {
    return (2.0 * NdotV) / (NdotV + sqrt(alpha + (1.0 - alpha) * (NdotV + NdotV)));
}

float G_CookTorrance(float NdotH, float NdotV, float VdotH, float NdotL) {
    float NdotH2 = 2.0 * NdotH;
    float g1 = (NdotH2 * NdotV) / VdotH;
    float g2 = (NdotH2 * NdotL) / VdotH;
    return min(1.0, min(g1, g2));
}

vec3 fresnelSchlick(float cosTheta, vec3 F0) {
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

vec3 schlickGaussian(float HdotL, vec3 F0) {
    float sphericalGaussian = exp2(((-5.55473 * HdotL) - 6.98316) * HdotL);
    return sphericalGaussian * (1.0 - F0) + F0;
}

float dielectricFresnel(float NdotV, float surfaceIOR) {
    float n1 = airIOR, n2 = surfaceIOR, eta = n1 / n2;
    float sinThetaT = eta * saturate(1.0 - (NdotV * NdotV));
    float cosThetaT = 1.0 - (sinThetaT * sinThetaT);

    float sPolar = pow((n2 * NdotV - n1 * cosThetaT) / (n2 * NdotV + n1 * cosThetaT), 2.0);
    float pPolar = pow((n2 * cosThetaT - n1 * NdotV) / (n2 * cosThetaT + n1 * NdotV), 2.0);

    return (sPolar + pPolar) * 0.5;
}

// https://d3ihk4j6ie4n1g.cloudfront.net/downloads/assets/DecimaSiggraph2017.pdf?mtime=20200402092944&focal=none
float NdotHSquared(float radiusTan, float NoL, float NoV, float VoL) {
    float radiusCos = 1.0 / sqrt(1.0 + radiusTan * radiusTan);
    
    // Early out if R falls within the disc
    float RoL = 2.0 * NoL * NoV - VoL;
    if(RoL >= radiusCos) return 1.0;

    float rOverLengthT = radiusCos * radiusTan * (1.0 / sqrt(1.0 - RoL * RoL));
    float NoTr = rOverLengthT * (NoV - RoL * NoL);
    float VoTr = rOverLengthT * (2.0 * NoV * NoV - 1.0 - RoL * VoL);

    // Calculate dot(cross(N, L), V). This could already be calculated and available.
    float triple = sqrt(saturate(1.0 - NoL * NoL - NoV * NoV - VoL * VoL + 2.0 * NoL * NoV * VoL));
    
    // Do one Newton iteration to improve the bent light vector
    float NoBr = rOverLengthT * triple, VoBr = rOverLengthT * (2.0 * triple * NoV);
    float NoLVTr = NoL * radiusCos + NoV + NoTr, VoLVTr = VoL * radiusCos + 1.0 + VoTr;
    float p = NoBr * VoLVTr, q = NoLVTr * VoLVTr, s = VoBr * NoLVTr;    
    float xNum = q * (-0.5 * p + 0.25 * VoBr * NoLVTr);
    float xDenom = p * p + s * ((s - 2.0 * p)) + NoLVTr * ((NoL * radiusCos + NoV) * VoLVTr * VoLVTr + 
                   q * (-0.5 * (VoLVTr + VoL * radiusCos) - 0.5));
    float twoX1 = 2.0 * xNum / (xDenom * xDenom + xNum * xNum);
    float sinTheta = twoX1 * xDenom;
    float cosTheta = 1.0 - twoX1 * xNum;
    NoTr = cosTheta * NoTr + sinTheta * NoBr; // use new T to update NoTr
    VoTr = cosTheta * VoTr + sinTheta * VoBr; // use new T to update VoTr
    
    // Calculate (N.H)^2 based on the bent light vector
    float newNoL = NoL * radiusCos + NoTr;
    float newVoL = VoL * radiusCos + VoTr;
    float NoH = NoV + newNoL;
    float HoH = 2.0 * newVoL + 2.0;
    return max(0.0, NoH * NoH / HoH);
}

// Provided by LVutner: more to read here: http://jcgt.org/published/0007/04/01/
vec3 sampleGGXVNDF(vec3 Ve, vec2 Xi, float alpha) {

	// Section 3.2: transforming the view direction to the hemisphere configuration
	vec3 Vh = normalize(vec3(alpha * Ve.xy, Ve.z));

	// Section 4.1: orthonormal basis (with special case if cross product is zero)
	float lensq = Vh.x * Vh.x + Vh.y * Vh.y;
	vec3 T1 = lensq > 0.0 ? vec3(-Vh.y, Vh.x, 0.0) * inversesqrt(lensq) : vec3(1.0, 0.0, 0.0);
	vec3 T2 = cross(T1, Vh);

	// Section 4.2: parameterization of the projected area
	float r = sqrt(Xi.y);	
	float xOffset = r * cos(PI2 * Xi.x);
	float yOffset = r * sin(PI2 * Xi.x);
	float s = 0.5 * (1.0 + Vh.z);
	yOffset = (1.0 - s) * sqrt(1.0 - (xOffset * xOffset)) + s * yOffset;

	// Section 4.3: reprojection onto hemisphere
	vec3 Nh = xOffset * T1 + yOffset * T2 + sqrt(max(0.0, 1.0 - (xOffset * xOffset) - (yOffset * yOffset))) * Vh;

	// Section 3.4: transforming the normal back to the ellipsoid configuration
	return normalize(vec3(alpha * Nh.x, alpha * Nh.y, max(0.0, Nh.z)));	
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

vec3 cookTorranceFresnel(float cosTheta, float F0, vec3 albedo, bool isMetal) {
    return isMetal ? schlickGaussian(cosTheta, albedo) : vec3(dielectricFresnel(cosTheta, F0toIOR(F0)));
}

vec3 cookTorranceSpecular(float NdotH, float HdotL, float NdotV, float NdotL, float roughness, float F0, vec3 albedo, bool isMetal) {
    float D = D_GGX(NdotH, roughness * roughness);
    vec3 F = cookTorranceFresnel(HdotL, F0, getSpecularColor(F0, albedo), isMetal);
    float G = G_Smith(NdotV, NdotL, roughness);
        
    return saturate((D * F * G) / max(0.0, 4.0 * NdotL * NdotV));
}

// OREN-NAYAR MODEL - QUALITATIVE 
// http://www1.cs.columbia.edu/CAVE/publications/pdfs/Oren_CVPR93.pdf
vec3 orenNayarDiffuse(vec3 N, vec3 V, vec3 L, float NdotL, float NdotV, float alpha, vec3 albedo) {
    vec2 angles = acos(vec2(NdotL, NdotV));
    if(angles.x < angles.y) angles = angles.yx;
    float cosA = saturate(dot(normalize(V - NdotV * N), normalize(L - NdotL * N)));

    vec3 A = albedo * (INV_PI - 0.09 * (alpha / (alpha + 0.4)));
    vec3 B = albedo * (0.125 * (alpha /  (alpha + 0.18)));
    return A + B * max(0.0, cosA) * sin(angles.x) * tan(angles.y);
}

// Thanks LVutner for the help!
// https://github.com/LVutner
vec3 cookTorrance(vec3 viewPos, vec3 N, vec3 L, material data, vec3 lightmap, vec3 shadowmap) {
    vec3 V = -normalize(viewPos);
    bool isMetal = data.F0 * 255.0 > 229.5;
    float alpha = data.roughness * data.roughness;

    vec3 H = normalize(V + L);
    float NdotV = max(EPS, dot(N, V));
    float NdotL = max(EPS, dot(N, L));
    float VdotL = max(EPS, dot(V, L));
    float HdotL = max(EPS, dot(H, L));
    float HdotV = max(EPS, dot(H, V));
    float NdotH = max(EPS, dot(N, H));

    vec3 specular = vec3(0.0);
    #if SPECULAR == 1
        specular = cookTorranceSpecular(NdotH, HdotL, NdotV, NdotL, data.roughness, data.F0, data.albedo, isMetal);
    #endif

    vec3 diffuse = vec3(0.0);
    if(!isMetal) { diffuse = orenNayarDiffuse(N, V, L, NdotL, NdotV, alpha, data.albedo); }

    /* Energy Conservation */
    vec3 F0vec = vec3(data.F0);
    vec3 energyConservationFactor = 1.0 - (4.0 * sqrt(F0vec) + 5.0 * vec3(F0vec) * vec3(F0vec)) * 0.11111111;
    vec3 fNdotL = 1.0 - schlickGaussian(NdotL, F0vec);
    vec3 fNdotV = 1.0 - schlickGaussian(NdotV, F0vec);

    vec3 fresnel = (fNdotL * fNdotV) / energyConservationFactor;
    diffuse *= fresnel;

    /* Calculating Indirect / Direct Lighting */
    vec3 Lighting = (diffuse + specular) * (NdotL * shadowmap) * SUN_INTENSITY * getDayColor();
    Lighting += data.emission * data.albedo;

    if(!isMetal) {
        vec3 ambient = GI == 0 ? AMBIENT : PTGI_AMBIENT;

        Lighting += ambient * data.albedo;
        #if GI == 0
            Lighting *= lightmap;
        #endif
    }
    return Lighting;
}
