/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

/*
    [Credits]
        LVutner - help with understanding the basics of BRDFs (https://github.com/LVutner)

    [References]:
        Karis, B. (2013). Specular BRDF Reference. http://graphicrants.blogspot.com/2013/08/specular-brdf-reference.html
        de Carpentier, G., & Ishiyama, K. (2017). DECIMA ENGINE: ADVANCES IN LIGHTING AND AA. https://www.guerrilla-games.com/media/News/Files/DecimaSiggraph2017.pdf
        Hammon, A., Jr. (2017). PBR Diffuse Lighting for GGX+Smith Microsurfaces. https://ubm-twvideo01.s3.amazonaws.com/o1/vault/gdc2017/Presentations/Hammon_Earl_PBR_Diffuse_Lighting.pdf
        Dupuy, J., & Benyoub, A. (2023). Sampling Visible GGX Normals with Spherical Caps. https://arxiv.org/pdf/2306.05044.pdf
*/

#include "/include/fragment/fresnel.glsl"

float distributionGGX(float cosThetaSq, float alphaSq) {
    return alphaSq / (PI * pow2(1.0 - cosThetaSq + cosThetaSq * alphaSq));
}

float lambdaSmith(float cosTheta, float alphaSq) {
    float cosThetaSq = pow2(cosTheta);
    return (-1.0 + sqrt(1.0 + alphaSq * (1.0 - cosThetaSq) / cosThetaSq)) * 0.5;
}

float G1SmithGGX(float cosTheta, float alphaSq) {
    return 1.0 / (1.0 + lambdaSmith(cosTheta, alphaSq));
}

float G2SmithGGX(float NdotL, float NdotV, float alphaSq) {
    float lambdaV = lambdaSmith(NdotV, alphaSq);
    float lambdaL = lambdaSmith(NdotL, alphaSq);
    return 1.0 / (1.0 + lambdaV + lambdaL);
}

vec3 sampleGGXVNDF(vec3 viewDirection, vec2 xi, float alpha) {
    viewDirection = normalize(vec3(alpha * viewDirection.xy, viewDirection.z));

    float cosTheta  = (1.0 - xi.y) * (1.0 + viewDirection.z) - viewDirection.z;
    float sinTheta  = sqrt(saturate(1.0 - cosTheta * cosTheta));
    vec3  reflected = vec3(sincos(TAU * xi.x).yx * sinTheta, cosTheta);

    vec3 halfway = reflected + viewDirection;

    return normalize(vec3(alpha * halfway.xy, halfway.z));
}

// This function assumes the light source is a sphere
float NdotHSquared(float angularRadius, float NdotL, float NdotV, float VdotL, out float newNdotL, out float newVdotL) {
    float radiusCos = cos(angularRadius), radiusTan = tan(angularRadius);
        
    float RdotL = 2.0 * NdotL * NdotV - VdotL;
    if(RdotL >= radiusCos) {
        newNdotL = 2.0 * NdotV - NdotV;
		newVdotL = 2.0 * NdotV * NdotV - 1.0;
        return 1.0;
    }

    float rOverLengthT = radiusCos * radiusTan * inversesqrt(1.0 - RdotL * RdotL);
    float NdotTr       = rOverLengthT * (NdotV - RdotL * NdotL);
    float VdotTr       = rOverLengthT * (2.0 * NdotV * NdotV - 1.0 - RdotL * VdotL);

    float triple = sqrt(saturate(1.0 - NdotL * NdotL - NdotV * NdotV - VdotL * VdotL + 2.0 * NdotL * NdotV * VdotL));
        
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
    return saturate(NdotH * NdotH / HdotH);
}

vec3 hammonDiffuse(Material material, vec3 viewDirection, vec3 lightDirection) {
    float NdotL = dot(material.normal, lightDirection);
    if(NdotL <= 0.0) return vec3(0.0);

    vec3 halfway = normalize(viewDirection + lightDirection);
    float NdotV  = saturate(dot(material.normal, viewDirection));
    float VdotL  = dot(viewDirection, lightDirection);
    float NdotH  = dot(material.normal, halfway);

    vec3 F0 = vec3(material.F0);

    float facing    = 0.5 + 0.5 * VdotL;
    float roughSurf = facing * (0.9 - 0.4 * facing) * (0.5 + NdotH / NdotH);

    vec3 energyConservationFactor = 1.0 - (4.0 * sqrt(F0) + 5.0 * F0 * F0) * rcp(9.0);
    vec3 fresnelL = fresnelDielectricDielectric_T(NdotL, vec3(airIOR), material.N);
    vec3 fresnelV = fresnelDielectricDielectric_T(NdotV, vec3(airIOR), material.N);

    vec3 smoothSurf = (fresnelL * fresnelV) / energyConservationFactor;
    vec3 single     = mix(smoothSurf, vec3(roughSurf), material.roughness) * RCP_PI;
    float multi     = 0.1159 * material.roughness;

    return NdotL * (material.albedo * multi + single);
}

vec3 hemisphericalAlbedo(vec3 n) {
    vec3 n2  = pow2(n);
    vec3 T_1 = (4.0 * (2.0 * n + 1.0)) / (3.0 * pow2(n + 1.0));
    vec3 T_2 = ((4.0 * pow3(n) * (n2 + 2.0 * n - 1.0)) / (pow2(n2 + 1.0) * (n2 - 1.0))) - 
               ((2.0 * n2 * (n2 + 1.0) * log(n)) / pow2(n2 - 1.0)) +
               ((2.0 * n2 * pow2(n2 - 1.0) * log((n * (n + 1.0)) / (n-  1.0))) / pow3(n2 + 1.0));
    return saturate(1.0 - 0.5 * (T_1 + T_2));
}

vec3 subsurfaceScatteringApprox(Material material, vec3 viewDirection, vec3 lightDirection, float distThroughMedium) {
    if(material.subsurface < EPS || distThroughMedium < EPS) return vec3(0.0);

    vec3 beer      = saturate(exp((material.albedo * 0.5 - 1.0) * max0(distThroughMedium) / material.subsurface));
    float cosTheta = -dot(lightDirection, viewDirection);

    // Phase function specifically made for leaves
    if(material.id == LEAVES_ID) {
        return beer * biLambertianPlatePhase(0.3, cosTheta);
    }

    vec3 isotropicLobe = beer * isotropicPhase;
    vec3 forwardsLobe  = beer * henyeyGreensteinPhase(cosTheta, 0.45);
    vec3 backwardsLobe = beer * henyeyGreensteinPhase(cosTheta,-0.45);

    return mix(isotropicLobe, mix(forwardsLobe, backwardsLobe, 0.3), 0.6);
}

vec3 computeDiffuse(vec3 viewDirection, vec3 lightDirection, Material material, vec4 shadowmap, vec3 directIlluminance, vec3 skyIlluminance, float ao, float cloudsShadows) {
    viewDirection = normalize(-viewDirection);

    vec3 diffuse  = hammonDiffuse(material, viewDirection, lightDirection);
         diffuse *= shadowmap.rgb * cloudsShadows;

    float skylightFalloff = getSkylightFalloff(material.lightmap.y);

    #if SUBSURFACE_SCATTERING == 1
        diffuse += subsurfaceScatteringApprox(material, viewDirection, lightDirection, shadowmap.a) * cloudsShadows * (material.id == SSS_ID ? skylightFalloff : 1.0);
    #endif

    diffuse *= directIlluminance;

    vec3 skylight = skyIlluminance;

    #if defined WORLD_OVERWORLD
        skylight *= skylightFalloff;
    #endif

    vec3 blocklightColor = getBlockLightColor(material);
    vec3 blocklight      = blocklightColor * getBlocklightFalloff(material.lightmap.x);
    vec3 emissiveness    = material.emission * blocklightColor;

    #if defined WORLD_OVERWORLD || defined WORLD_END
        vec3 ambient = vec3(0.2);
    #else
        vec3 ambient = vec3(1.0);
    #endif

    diffuse += (blocklight + skylight + ambient) * material.ao * ao;
    diffuse += emissiveness;

    return material.albedo * diffuse;
}

vec3 computeSpecular(Material material, vec3 viewDirection, vec3 lightDirection) {
    float NdotL = dot(material.normal, lightDirection);
    if(NdotL <= 0.0) return vec3(0.0);

    float alphaSq = maxEps(material.roughness * material.roughness);

    float NdotV = dot(material.normal, viewDirection);
    float VdotL = dot(viewDirection,   lightDirection);

    float NdotHSq = NdotHSquared(shadowLightAngularRadius, NdotL, NdotV, VdotL, NdotL, VdotL);
    float VdotH   = (VdotL + 1.0) * inversesqrt(2.0 * VdotL + 2.0);

    NdotV = abs(NdotV);
    
    float D  = distributionGGX(NdotHSq, alphaSq);
    vec3  F  = fresnelDielectricConductor(VdotH, material.N, material.K);
    float G2 = G2SmithGGX(NdotL, NdotV, alphaSq);
        
    return NdotL * F * D * G2 / maxEps(4.0 * NdotL * NdotV);
}
