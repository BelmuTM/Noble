/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

// http://graphicrants.blogspot.com/2013/08/specular-brdf-reference.html
float distributionGGX(float NdotH, float roughness) {
    float alpha2 = pow4(roughness);
    float denom  = (NdotH * alpha2 - NdotH) * NdotH + 1.0;
    return alpha2 / pow2(denom) * INV_PI;
}

// Thanks LVutner#5199 for providing lambda smith equation
float lambdaSmith(float cosTheta, float alpha) {
    float cosTheta2 = pow2(cosTheta);
    return (-1.0 + sqrt(1.0 + alpha * (1.0 - cosTheta2) / cosTheta2)) * 0.5;
}

float G1SmithGGX(float cosTheta, float roughness) {
    float alpha = pow2(roughness);
    return 1.0 / (1.0 + lambdaSmith(cosTheta, alpha));
}

float G2SmithGGX(float NL, float NV, float roughness) {
    float alpha   = pow2(roughness);
    float lambdaV = lambdaSmith(NV, alpha);
    float lambdaL = lambdaSmith(NL, alpha);
    return 1.0 / (1.0 + lambdaV + lambdaL);
}

// https://seblagarde.wordpress.com/2013/04/29/memo-on-fresnel-equations/
float fresnelDielectric(float NdotV, float surfaceIOR) {
    float n1 = airIOR, n2 = surfaceIOR;
    float sinThetaT = (n1 / n2) * max0(1.0 - pow2(NdotV));
    float cosThetaT = 1.0 - pow2(sinThetaT);

    if(sinThetaT >= 1.0) { return 1.0; }

    float sPolar = (n2 * NdotV - n1 * cosThetaT) / (n2 * NdotV + n1 * cosThetaT);
    float pPolar = (n2 * cosThetaT - n1 * NdotV) / (n2 * cosThetaT + n1 * NdotV);

    return clamp01((pow2(sPolar) + pow2(pPolar)) * 0.5);
}

vec3 fresnelDielectric(float NdotV, vec3 surfaceIOR) {
    vec3 n1 = vec3(airIOR), n2 = surfaceIOR;
    vec3 sinThetaT = (n1 / n2) * max0(1.0 - pow2(NdotV));
    vec3 cosThetaT = 1.0 - pow2(sinThetaT);

    vec3 sPolar = (n2 * NdotV - n1 * cosThetaT) / (n2 * NdotV + n1 * cosThetaT);
    vec3 pPolar = (n2 * cosThetaT - n1 * NdotV) / (n2 * cosThetaT + n1 * NdotV);

    return clamp01((pow2(sPolar) + pow2(pPolar)) * 0.5);
}

vec3 fresnelDieletricConductor(vec3 eta, vec3 etaK, float cosTheta) {  
   float cosTheta2 = cosTheta * cosTheta;
   float sinTheta2 = 1.0 - cosTheta2;
   vec3 eta2  = eta * eta;
   vec3 etaK2 = etaK * etaK;

   vec3 t0   = eta2 - etaK2 - sinTheta2;
   vec3 a2b2 = sqrt(t0 * t0 + 4.0 * eta2 * etaK2);
   vec3 t1   = a2b2 + cosTheta2;
   vec3 a    = sqrt(0.5 * (a2b2 + t0));
   vec3 t2   = 2.0 * a * cosTheta;
   vec3 Rs   = (t1 - t2) / (t1 + t2);

   vec3 t3 = cosTheta2 * a2b2 + sinTheta2 * sinTheta2;
   vec3 t4 = t2 * sinTheta2;   
   vec3 Rp = Rs * (t3 - t4) / (t3 + t4);

   return clamp01((Rp + Rs) * 0.5);
}

// Provided by LVutner: more to read here: http://jcgt.org/published/0007/04/01/
// Modified by Belmu
vec3 sampleGGXVNDF(vec3 viewDir, vec2 seed, float roughness) {
    float alpha = pow2(roughness);
    
	// Transforming the view direction to the hemisphere configuration
	viewDir = normalize(vec3(alpha * viewDir.xy, viewDir.z));

	// Orthonormal basis (with special case if cross product is zero)
	float lensq = dot(viewDir.yx, viewDir.yx);
	vec3 T1     = vec3(lensq > 0.0 ? vec2(-viewDir.y, viewDir.x) * inversesqrt(lensq) : vec2(1.0, 0.0), 0.0);
	vec3 T2     = cross(T1, viewDir);

	// Parameterization of the projected area
	float r   = sqrt(seed.x);
    float phi = TAU * seed.y;
	float t1  = r * cos(phi);
    float tmp = clamp01(1.0 - pow2(t1));
	float t2  = mix(sqrt(tmp), r * sin(phi), 0.5 + 0.5 * viewDir.z);

	// Reprojection onto hemisphere
	vec3 Nh = t1 * T1 + t2 * T2 + sqrt(clamp01(tmp - pow2(t2))) * viewDir;

	// Transforming the normal back to the ellipsoid configuration
	return normalize(vec3(alpha * Nh.xy, Nh.z));	
}

// HAMMON DIFFUSE
// https://ubm-twvideo01.s3.amazonaws.com/o1/vault/gdc2017/Presentations/Hammon_Earl_PBR_Diffuse_Lighting.pdf
vec3 hammonDiffuse(vec3 N, vec3 V, vec3 L, Material mat, bool pt) {
    float alpha = pow2(mat.rough);

    vec3 H      = normalize(V + L);
    float VdotL = maxEps(dot(V, L));
    float NdotH = maxEps(dot(N, H));
    float NdotV = maxEps(dot(N, V));
    float NdotL = clamp01(dot(N, L));

    float facing    = 0.5 + 0.5 * VdotL;
    float roughSurf = facing * (0.9 - 0.4 * facing) * (0.5 + NdotH / NdotH);

    // Concept of replacing smooth surface by Lambertian with energy conservation from LVutner#5199
    float smoothSurf;
    if(!pt) {
        float energyConservationFactor = 1.0 - (4.0 * sqrt(mat.F0) + 5.0 * mat.F0 * mat.F0) * (1.0 / 9.0);
        float ior       = F0ToIOR(mat.F0);
        float fresnelNL = 1.0 - fresnelDielectric(NdotL, ior);
        float fresnelNV = 1.0 - fresnelDielectric(NdotV, ior);

        smoothSurf = (fresnelNL * fresnelNV) / energyConservationFactor;
    } else {
        smoothSurf = 1.05 * (1.0 - pow5(1.0 - NdotL)) * (1.0 - pow5(1.0 - NdotV));
    }
    float single = mix(smoothSurf, roughSurf, alpha) * INV_PI;
    float multi  = 0.1159 * alpha;

    if(pt) { return clamp01(single + mat.albedo * multi);           }
    else   { return clamp01(NdotL * (mat.albedo * multi + single)); }
}

// Disney SSS from: https://www.shadertoy.com/view/XdyyDd
float disneySubsurface(vec3 N, vec3 V, vec3 L, Material mat) {
    vec3 H      = normalize(V + L);
    float NdotV = clamp01(dot(N, V));
    float NdotL = clamp01(dot(N, L));
    float LdotH = clamp01(dot(L, H));

    float FL    = cornetteShanksPhase(NdotL, 0.5), FV = cornetteShanksPhase(NdotV, 0.5);
    float Fss90 = LdotH * LdotH * mat.rough;
    float Fss   = mix(1.0, Fss90, FL) * mix(1.0, Fss90, FV);
    float ss    = 1.25 * (Fss * (1.0 / (NdotL + NdotV) - 0.5) + 0.5);

    return quintic(0.0, 1.0, ss);
}

vec3 fresnelComplex(float cosTheta, Material mat) {
    mat2x3 hcm = getHardcodedMetal(mat);
    return mat.isMetal ? fresnelDieletricConductor(hcm[0], hcm[1], cosTheta) : vec3(fresnelDielectric(cosTheta, F0ToIOR(mat.F0)));
}

vec3 computeSpecular(vec3 N, vec3 V, vec3 L, Material mat) {
    vec3 H      = normalize(V + L);
    float NdotV = maxEps(dot(N, V));
    float NdotL = clamp01(dot(N, L));
    float HdotL = dot(H, L);
    float NdotH = dot(N, H);

    float D  = distributionGGX(NdotH, mat.rough);
    vec3  F  = fresnelComplex(HdotL, mat);
    float G2 = G2SmithGGX(NdotV, NdotL, mat.rough);
        
    return clamp01(NdotL * (D * F * G2) / maxEps(4.0 * NdotL * NdotV));
}

// Thanks LVutner and Jessie for the help!
// https://github.com/LVutner
// https://github.com/Jessie-LC

vec3 computeDiffuse(vec3 V, vec3 L, Material mat, vec4 shadowmap, vec3 directLight, vec3 skyIlluminance) {
    if(mat.isMetal) return vec3(0.0);

    V = -normalize(V);
    vec3 diffuse = hammonDiffuse(mat.normal, V, L, mat, false) * shadowmap.rgb;

    #if SUBSURFACE_SCATTERING == 1
        diffuse = mix(diffuse, disneySubsurface(mat.normal, V, L, mat) * mat.albedo, mat.subsurface);
    #endif

    mat.lightmap.x = BLOCKLIGHTMAP_MULTIPLIER * pow(quintic(0.0, 1.0, mat.lightmap.x), BLOCKLIGHTMAP_EXPONENT);
    mat.lightmap.y = pow2(1.0 - pow(1.0 - clamp01(mat.lightmap.y), 0.5));

    vec3 skyLight   = skyIlluminance * INV_PI * mat.lightmap.y;
    vec3 blockLight = temperatureToRGB(BLOCKLIGHT_TEMPERATURE) * BLOCKLIGHT_MULTIPLIER * mat.lightmap.x;

    diffuse  = directLight * diffuse;
    diffuse += blockLight  + (skyLight * (mat.ao * shadowmap.a));
    return mat.albedo * diffuse;
}
