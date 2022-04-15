/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

// http://graphicrants.blogspot.com/2013/08/specular-brdf-reference.html
float distributionGGX(float NdotH2, float roughness) {
    float alpha2 = pow4(roughness);
    return alpha2 / (PI * pow2(1.0 - NdotH2 + NdotH2 * alpha2));
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

float G2SmithGGX(float NdotL, float NdotV, float roughness) {
    float alpha   = pow2(roughness);
    float lambdaV = lambdaSmith(NdotV, alpha);
    float lambdaL = lambdaSmith(NdotL, alpha);
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
    float NdotL = maxEps(dot(N, L));
    float NdotV = maxEps(dot(N, V));
    float VdotL = dot(V, L);
    float NdotH = dot(N, H);

    float facing    = 0.5 + 0.5 * VdotL;
    float roughSurf = facing * (0.9 - 0.4 * facing) * (0.5 + NdotH / NdotH);

    // Concept of replacing smooth surface by Lambertian with energy conservation from LVutner#5199
    float smoothSurf;
    if(!pt) {
        float energyConservationFactor = 1.0 - (4.0 * sqrt(mat.F0) + 5.0 * mat.F0 * mat.F0) * (1.0 / 9.0);
        float ior       = F0ToIOR(mat.F0);
        float fresnelNL = 1.0 - fresnelDielectric(NdotL, ior);
        float fresnelNV = 1.0 - fresnelDielectric(NdotV, ior);

        smoothSurf = fresnelNL * fresnelNV * (1.0 / energyConservationFactor);
    } else {
        smoothSurf = 1.05 * (1.0 - pow5(1.0 - NdotL)) * (1.0 - pow5(1.0 - NdotV));
    }
    float single = mix(smoothSurf, roughSurf, alpha) * INV_PI;
    float multi  = 0.1159 * alpha;

    if(pt) { return single + mat.albedo * multi;           }
    else   { return NdotL * (mat.albedo * multi + single); }
}

// Disney SSS from: https://www.shadertoy.com/view/XdyyDd
float disneySubsurface(vec3 N, vec3 V, vec3 L, Material mat) {
    vec3 H      = normalize(V + L);
    float NdotL = clamp01(dot(N, L));
    float NdotV = clamp01(dot(N, V));
    float HdotL = clamp01(dot(L, H));

    float FL    = cornetteShanksPhase(NdotL, 0.5), FV = cornetteShanksPhase(NdotV, 0.5);
    float Fss90 = pow2(HdotL) * mat.rough;
    float Fss   = mix(1.0, Fss90, FL) * mix(1.0, Fss90, FV);
    float ss    = 1.25 * (Fss * (1.0 / (NdotL + NdotV) - 0.5) + 0.5);

    return quintic(0.0, 1.0, ss);
}

vec3 fresnelComplex(float cosTheta, Material mat) {
    mat2x3 hcm = getHardcodedMetal(mat);
    return mat.isMetal ? fresnelDieletricConductor(hcm[0], hcm[1], cosTheta) : vec3(fresnelDielectric(cosTheta, F0ToIOR(mat.F0)));
}

// This function helps us consider the light source as a sphere
// https://www.guerrilla-games.com/read/decima-engine-advances-in-lighting-and-aa
float NdotHSquared(float angularRadius, float NdotL, float NdotV, float VdotL, out float newNdotL, out float newVdotL) {
    float radiusCos = cos(angularRadius), radiusTan = tan(angularRadius);
        
    float RdotL = 2.0 * NdotL * NdotV - VdotL;
    if(RdotL >= radiusCos) return 1.0;

    float rOverLengthT = radiusCos * radiusTan * inversesqrt(1.0 - RdotL * RdotL);
    float NdotTr       = rOverLengthT * (NdotV - RdotL * NdotL);
    float VdotTr       = rOverLengthT * (2.0 * NdotV * NdotV - 1.0 - RdotL * VdotL);

    float triple = sqrt(clamp01(1.0 - NdotL * NdotL - NdotV * NdotV - VdotL * VdotL + 2.0 * NdotL * NdotV * VdotL));
        
    float NdotBr   = rOverLengthT * triple, VdotBr = rOverLengthT * (2.0 * triple * NdotV);
    float NdotLVTr = NdotL * radiusCos + NdotV + NdotTr, VdotLVTr = VdotL * radiusCos + 1.0 + VdotTr;
    float p        = NdotBr * VdotLVTr, q = NdotLVTr * VdotLVTr, s = VdotBr * NdotLVTr;    
    float xNum     = q * (-0.5 * p + 0.25 * VdotBr * NdotLVTr);
    float xDenom   = p * p + s * ((s - 2.0 * p)) + NdotLVTr * ((NdotL * radiusCos + NdotV) * VdotLVTr * VdotLVTr + q * (-0.5 * (VdotLVTr + VdotL * radiusCos) - 0.5));
    float twoX1    = 2.0 * xNum / (xDenom * xDenom + xNum * xNum);
    float sinTheta = twoX1 * xDenom;
    float cosTheta = 1.0 - twoX1 * xNum;

    NdotTr = cosTheta * NdotTr + sinTheta * NdotBr;
    VdotTr = cosTheta * VdotTr + sinTheta * VdotBr;

    newNdotL = NdotL * radiusCos + NdotTr;
    newVdotL = VdotL * radiusCos + VdotTr;

    float NdotH = NdotV + newNdotL;
    float HdotH = 2.0 * newVdotL + 2.0;
    return clamp01(NdotH * NdotH / HdotH);
}

vec3 computeSpecular(vec3 N, vec3 V, vec3 L, Material mat) {
    vec3 H      = normalize(V + L);
    float NdotV = dot(N, V);
    float NdotL = dot(N, L);
    float VdotL = dot(V, L);
    float VdotH = dot(V, H);

    float NdotH = NdotHSquared(shadowLightAngularRad, NdotL, NdotV, VdotL, NdotV, VdotL);
          VdotH = (VdotL + 1.0) * inversesqrt(2.0 * VdotL + 2.0);

    NdotV    = maxEps(NdotV);
    float D  = distributionGGX(NdotH, mat.rough);
    vec3  F  = fresnelComplex(VdotH, mat);
    float G2 = G2SmithGGX(NdotL, NdotV, mat.rough);
        
    return clamp01(clamp01(NdotL) * (D * G2) * F / (4.0 * NdotL * NdotV));
}

// Thanks LVutner and Jessie for the help!
// https://github.com/LVutner
// https://github.com/Jessie-LC

vec3 computeDiffuse(vec3 V, vec3 L, Material mat, vec4 shadowmap, vec3 directLight, vec3 skyIlluminance) {
    //vec3 shadowPos      = (transMAD(shadowModelView, viewToScene(V)) / cloudsShadowmapDist) * 0.5 + 0.5;
    //float cloudsShadows = texture(colortex2, shadowPos.xy / cloudsShadowmapRes).r;

    V = -normalize(V);

    vec3 diffuse  = hammonDiffuse(mat.normal, V, L, mat, false);
         diffuse *= shadowmap.rgb;

    #if SUBSURFACE_SCATTERING == 1
        diffuse += (mat.albedo * disneySubsurface(mat.normal, V, L, mat) * mat.subsurface);
    #endif

    diffuse *= directLight;

    mat.lightmap.x = pow2(quintic(0.0, 1.0, mat.lightmap.x));
    mat.lightmap.y = pow2(1.0 - pow(1.0 - clamp01(mat.lightmap.y), SKYLIGHT_FALLOFF));

    vec3 skyLight   = skyIlluminance * INV_PI * mat.lightmap.y;
    vec3 blockLight = getBlockLightIntensity(mat) * mat.lightmap.x;
         diffuse   += (blockLight + skyLight) * (mat.ao * shadowmap.a);

    return mat.albedo * diffuse;
}
