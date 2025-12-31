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
    [Credits]
        LVutner - help with understanding the basics of BRDFs (https://github.com/LVutner)

    [References]:
        Karis, B. (2013). Specular BRDF Reference. http://graphicrants.blogspot.com/2013/08/specular-brdf-reference.html
        de Carpentier, G., & Ishiyama, K. (2017). DECIMA ENGINE: ADVANCES IN LIGHTING AND AA. https://www.guerrilla-games.com/media/News/Files/DecimaSiggraph2017.pdf
        Hammon, A., Jr. (2017). PBR Diffuse Lighting for GGX+Smith Microsurfaces. https://ubm-twvideo01.s3.amazonaws.com/o1/vault/gdc2017/Presentations/Hammon_Earl_PBR_Diffuse_Lighting.pdf
        Dupuy, J., & Benyoub, A. (2024). Sampling Visible GGX Normals with Spherical Caps. https://arxiv.org/pdf/2306.05044.pdf
*/

#include "/include/fragment/fresnel.glsl"

//////////////////////////////////////////////////////////
/*------------------ GGX DISTRIBUTION ------------------*/
//////////////////////////////////////////////////////////

float distribution_GGX(float cosTheta, float alphaSq) {
    float denom = cosTheta * cosTheta * (alphaSq - 1.0) + 1.0;
    return alphaSq * RCP_PI / (denom * denom);
}

float lambda_Smith(float cosTheta, float alphaSq) {
    float cosThetaSq = cosTheta * cosTheta;
    return (-1.0 + sqrt(1.0 + alphaSq * (1.0 - cosThetaSq) / cosThetaSq)) * 0.5;
}

//////////////////////////////////////////////////////////
/*-------------------- MICROSURFACE --------------------*/
//////////////////////////////////////////////////////////

float smithG_GGX(float cosTheta, float alphaSq) {
    float cosThetaSq = cosTheta * cosTheta;
    return 1.0 / maxEps(cosTheta + sqrt(alphaSq + cosThetaSq - alphaSq * cosThetaSq));
}

float G1_Smith_GGX(float cosTheta, float alphaSq) {
    return 1.0 / (1.0 + lambda_Smith(cosTheta, alphaSq));
}

float G2_Smith_Height_Correlated(float NdotV, float NdotL, float alphaSq) {
    float lambdaV = lambda_Smith(NdotV, alphaSq);
    float lambdaL = lambda_Smith(NdotL, alphaSq);
    return 1.0 / (1.0 + lambdaV + lambdaL);
}

float G2_Smith_Separable(float NdotV, float NdotL, float alphaSq) {
    return smithG_GGX(NdotV, alphaSq) * smithG_GGX(NdotL, alphaSq);
}

vec3 sampleGGXVNDF(vec3 viewDirection, vec2 xi, float alpha) {
    viewDirection = normalize(vec3(alpha * viewDirection.xy, viewDirection.z));

    float cosTheta  = (1.0 - xi.y) * (1.0 + viewDirection.z) - viewDirection.z;
    float sinTheta  = sqrt(saturate(1.0 - cosTheta * cosTheta));
    vec3  reflected = vec3(sincos(TAU * xi.x).yx * sinTheta, cosTheta);

    vec3 halfway = reflected + viewDirection;

    return normalize(vec3(alpha * halfway.xy, halfway.z));
}

//////////////////////////////////////////////////////////
/*----------------------- DIFFUSE ----------------------*/
//////////////////////////////////////////////////////////

vec3 hammonDiffuse(Material material, vec3 viewDirection, vec3 lightDirection) {
    float NdotL = dot(material.normal, lightDirection);
    if (NdotL <= 0.0) return vec3(0.0);

    vec3 halfway = normalize(viewDirection + lightDirection);
    float NdotV  = saturate(dot(material.normal, viewDirection));
    float VdotL  = dot(viewDirection, lightDirection);
    float NdotH  = dot(material.normal, halfway);

    vec3 F0 = vec3(material.F0);

    float facing    = 0.5 + 0.5 * VdotL;
    float roughSurf = facing * (0.9 - 0.4 * facing) * (fastInvSqrtN1(NdotH * NdotH + 1e-2) + 2.0);

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
    if (material.subsurface < EPS || distThroughMedium < EPS) return vec3(0.0);

    vec3 beer      = saturate(exp((material.albedo * 0.5 - 1.0) * max0(distThroughMedium) / material.subsurface));
    float cosTheta = -dot(lightDirection, viewDirection);

    // Phase function specifically made for leaves
    if (material.id == LEAVES_ID) {
        return beer * biLambertianPlatePhase(0.3, cosTheta);
    }

    vec3 isotropicLobe = beer * isotropicPhase;
    vec3 forwardsLobe  = beer * henyeyGreensteinPhase(cosTheta, 0.45);
    vec3 backwardsLobe = beer * henyeyGreensteinPhase(cosTheta,-0.45);

    return mix(isotropicLobe, mix(forwardsLobe, backwardsLobe, 0.3), 0.6);
}

vec3 computeDiffuse(vec3 viewDirection, vec3 lightDirection, Material material, bool isMetal, vec4 shadowmap, vec3 directIlluminance, vec3 skyIlluminance, float ao, float cloudsShadows) {
    if (material.id == LIGHTNING_BOLT_ID) return vec3(1e7);

    viewDirection = normalize(-viewDirection);

    vec3 diffuse;
    if (isMetal) {
        // Lambert
        diffuse = vec3(max0(dot(material.normal, lightDirection)) * RCP_PI);
    } else {
        diffuse = hammonDiffuse(material, viewDirection, lightDirection);
    }

    diffuse *= shadowmap.rgb * cloudsShadows;

    float skylightFalloff = getSkylightFalloff(material.lightmap.y);

    #if SUBSURFACE_SCATTERING == 1
        if (!isMetal) {
            diffuse += subsurfaceScatteringApprox(material, viewDirection, lightDirection, shadowmap.a) * cloudsShadows * skylightFalloff;
        }
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
        const vec3 ambient = vec3(0.0);
    #else
        const vec3 ambient = vec3(1.9, 0.8, 0.1) * 5.0;
    #endif

    diffuse += (blocklight + skylight + ambient) * material.ao * ao;
    diffuse += emissiveness;

    return material.albedo * diffuse;
}

// Pathtracing shenanigans

vec3 evaluateMicrosurfaceOpaque(vec2 hitPosition, vec3 wi, vec3 wo, Material material, vec3 directIlluminance) {
    bool isMetal = material.F0 * maxFloat8 > labPBRMetals;

    vec3 diffuse;
    if (isMetal) {
        // Lambert
        diffuse = vec3(max0(dot(material.normal, wo)) * RCP_PI);
    } else {
        diffuse = hammonDiffuse(material, wi, wo);
    }

    vec4 shadowmap = texture(SHADOWMAP_BUFFER, max(hitPosition, texelSize));

    #if SUBSURFACE_SCATTERING == 1
        diffuse += subsurfaceScatteringApprox(material, wi, wo, shadowmap.a) * float(material.lightmap.y > EPS);
    #endif

    return diffuse * shadowmap.rgb * directIlluminance;
}

vec3 sampleMicrosurfaceOpaquePhase(inout vec3 estimate, inout vec3 wr, Material material) {
    mat3 tbn        = calculateTBN(material.normal);
    vec3 microfacet = tbn * sampleGGXVNDF(-wr * tbn, rand2F(), material.roughness);
    vec3 fresnel    = fresnelDielectricConductor(dot(microfacet, -wr), material.N, material.K);

    wr = generateCosineVector(microfacet, rand2F());

    vec3 energyConservationFactor = 1.0 - hemisphericalAlbedo(material.N);

    vec3 phase = vec3(0.0);
    phase     = 1.0 - fresnel;
    phase    /= abs(energyConservationFactor);
    phase    *= material.albedo * material.ao;
    estimate += material.albedo * EMISSIVE_INTENSITY * material.emission;
    phase    *= fresnelDielectricDielectric_T(dot(microfacet, wr), vec3(airIOR), material.N);
    
    return phase;
}

//////////////////////////////////////////////////////////
/*---------------------- SPECULAR ----------------------*/
//////////////////////////////////////////////////////////

// This function assumes the light source is a sphere
float NdotHSquared(float angularRadius, float NdotL, float NdotV, float VdotL, out float newNdotL, out float newVdotL) {
    float radiusCos = cos(angularRadius), radiusTan = tan(angularRadius);
        
    float RdotL = 2.0 * NdotL * NdotV - VdotL;
    if (RdotL >= radiusCos) {
        newNdotL = 2.0 * NdotV - NdotV;
        newVdotL = 2.0 * NdotV * NdotV - 1.0;
        return 1.0;
    }

    float rOverLengthT = radiusCos * radiusTan * fastInvSqrtN1(1.0 - RdotL * RdotL);
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

vec3 computeSpecular(Material material, vec3 viewDirection, vec3 lightDirection) {
    float NdotL = dot(material.normal, lightDirection);
    if (NdotL <= 0.0) return vec3(0.0);

    float alphaSq = maxEps(material.roughness * material.roughness);

    float NdotV = dot(material.normal, viewDirection);
    float VdotL = dot(viewDirection,   lightDirection);

    float NdotHSq = NdotHSquared(shadowLightAngularRadius, NdotL, NdotV, VdotL, NdotL, VdotL);
    float VdotH   = (VdotL + 1.0) * fastInvSqrtN1(2.0 * VdotL + 2.0);

    NdotV = abs(NdotV);
    
    float D  = distribution_GGX(sqrt(NdotHSq), alphaSq);
    vec3  F  = fresnelDielectricConductor(VdotH, material.N, material.K);
    float G2 = G2_Smith_Height_Correlated(NdotV, NdotL, alphaSq);
        
    return NdotL * D * F * G2 / maxEps(4.0 * NdotL * NdotV);
}
