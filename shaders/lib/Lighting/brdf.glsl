/***********************************************/
/*       Copyright (C) Noble RT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

float trowbridgeReitzGGX(float NdotH, float alpha) {
    // GGXTR(N,H,α) = α² / π*((N*H)²*(α² + 1)-1)²
    float denom = ((NdotH * NdotH) * (alpha - 1.0) + 1.0);
    return alpha / (PI * denom * denom);
}

float geometrySchlickBeckmann(float cosTheta, float roughness) {
    // SchlickGGX(N,V,k) = N*V/(N*V)*(1 - k) + k
    float denom = cosTheta * (1.0 - roughness) + roughness;
    return cosTheta / denom;
}

float geometrySmith(float NdotV, float NdotL, float roughness) {
    float r = roughness + 1.0;
    roughness = (r * r) / 8.0;

    float ggxV = geometrySchlickBeckmann(NdotV, roughness);
    float ggxL = geometrySchlickBeckmann(NdotL, roughness);
    return (ggxV * ggxL) / max(4.0 * NdotL * NdotV, EPS);
}

float geometrySchlickGGX(float NdotV, float alpha) {
    float a2 = alpha * alpha;
    return (2.0 * NdotV) / (NdotV + sqrt(a2 + (1.0 - a2) * (NdotV + NdotV)));
}

float geometryCookTorrance(float NdotH, float NdotV, float VdotH, float NdotL) {
    float NdotH2 = 2.0 * NdotH;
    float g1 = (NdotH2 * NdotV) / VdotH;
    float g2 = (NdotH2 * NdotL) / VdotH;
    return min(1.0, min(g1, g2));
}

vec3 fresnelSchlick(float cosTheta, vec3 F0) {
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

vec3 sphericalGaussianFresnel(float HdotL, vec3 F0) {
    float fresnel = exp2(((-5.55473 * HdotL) - 6.98316) * HdotL);
    return fresnel * (1.0 - F0) + F0;
}

// Provided by LVutner: more to read here: http://jcgt.org/published/0007/04/01/
vec3 sampleGGXVNDF(vec3 Ve, vec2 Xi, float roughness) {
    float alpha = roughness * roughness;

	// Section 3.2: transforming the view direction to the hemisphere configuration
	vec3 Vh = normalize(vec3(alpha * Ve.x, alpha * Ve.y, Ve.z));

	// Section 4.1: orthonormal basis (with special case if cross product is zero)
	float lensq = Vh.x * Vh.x + Vh.y * Vh.y;
	vec3 T1 = lensq > 0.0 ? vec3(-Vh.y, Vh.x, 0.0) * inversesqrt(lensq) : vec3(1.0, 0.0, 0.0);
	vec3 T2 = cross(Vh, T1);

	// Section 4.2: parameterization of the projected area
	float r = sqrt(Xi.y);	
	float phi = 2.0 * PI * Xi.x;	
	float t1 = r * cos(phi);
	float t2 = r * sin(phi);
	float s = 0.5 * (1.0 + Vh.z);
	t2 = (1.0 - s) * sqrt(1.0 - t1 * t1) + s * t2;

	// Section 4.3: reprojection onto hemisphere
	vec3 Nh = t1 * T1 + t2 * T2 + sqrt(max(0.0, 1.0 - t1 * t1 - t2 * t2)) * Vh;

	// Section 3.4: transforming the normal back to the ellipsoid configuration
	return normalize(vec3(alpha * Nh.x, alpha * Nh.y, max(0.0, Nh.z)));	
}

// https://www.unrealengine.com/en-US/blog/physically-based-shading-on-mobile?sessionInvalidated=true
vec3 envBRDFApprox(vec3 specular, float NdotV, float roughness) {
    const vec4 c0 = vec4(-1.0, -0.0275, -0.572, 0.022);
    const vec4 c1 = vec4(1.0, 0.0425, 1.04, -0.04);
    vec4 r = roughness * c0 + c1;
    float a004 = min(r.x * r.x, exp2(-9.28 * NdotV)) * r.x + r.y;
    vec2 AB = vec2(-1.04, 1.04) * a004 + r.zw;
    return specular * AB.x + AB.y;
}

/*
    Thanks LVutner for the help!
    https://github.com/LVutner
    https://gist.github.com/LVutner/c07a3cc4fec338e8fe3fa5e598787e47
*/

vec3 cookTorrance(vec3 N, vec3 V, vec3 L, material data, vec3 lightmap, vec3 shadowmap, vec3 GlobalIllumination) {
    bool isMetal = (data.F0 * 255.0) > 229.5;
    float alpha = data.roughness * data.roughness;

    vec3 specularColor = isMetal ? data.albedo : vec3(data.F0);
    vec3 dayTimeColor = getDayTimeColor();

    vec3 H = normalize(V + L);
    float NdotL = saturate(dot(N, L));
    float NdotV = saturate(dot(N, V));
    float NdotH = saturate(dot(N, H));
    float VdotH = saturate(dot(V, H));
    float HdotL = saturate(dot(H, L));

    vec3 SpecularLighting;
    #if SPECULAR == 1
        float D = trowbridgeReitzGGX(NdotH, alpha);
        vec3 F = sphericalGaussianFresnel(HdotL, specularColor);
        float G = geometrySmith(NdotV, NdotL, data.roughness);
        
        SpecularLighting = (D * F * G) * shadowmap * dayTimeColor;
    #endif

    vec3 DiffuseLighting = vec3(0.0);
    vec3 E0 = lightmap + NdotL * shadowmap + AMBIENT;
    vec3 Albedo = (data.albedo * dayTimeColor) * INV_PI;

    if(!isMetal) {
        /* 
            OREN-NAYAR MODEL - QUALITATIVE 
            http://www1.cs.columbia.edu/CAVE/publications/pdfs/Oren_CVPR93.pdf
        */
        /*
        vec2 angles = acos(vec2(NdotL, NdotV));
        if(angles.x < angles.y) angles = angles.yx;
        float cosA = saturate(dot(normalize(V - NdotV * N), normalize(L - NdotL * N)));

        vec3 A = Albedo * (INV_PI - 0.09 * (alpha / (alpha + 0.4)));
        vec3 B = Albedo * (0.125 * (alpha /  (alpha + 0.18)));

        DiffuseLighting = clamp(NdotL * (A + B * max(0.0, cosA) * sin(angles.x) * tan(angles.y)) * E0, 0.0, 1.0);
        DiffuseLighting = DiffuseLighting + (GlobalIllumination * data.albedo);
        */

        /* OREN-NAYAR MODEL - QUALITATIVE SIMPLIFIED */
        float aNdotL = ACos(NdotL), aNdotV = ASin(NdotV);
        float A = 1.0 - 0.5 * (alpha / (alpha + 0.33));
        float B = 0.45 * alpha / (alpha + 0.09);

        DiffuseLighting = Albedo * (A + (B * max(EPS, cos(aNdotV - aNdotL)))) * E0;
        DiffuseLighting = DiffuseLighting + (GlobalIllumination * data.albedo);
    }

    vec3 Lighting = DiffuseLighting + SpecularLighting;
    Lighting += (data.albedo * data.emission);

    return Lighting;
}
