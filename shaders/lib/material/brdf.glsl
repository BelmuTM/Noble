/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

float Phong(vec3 lightDir, vec3 rayDir, vec3 normal, float shininess) {
    vec3 reflectDir = reflect(-lightDir, normal);
    float specAngle = max(dot(reflectDir, rayDir), 0.0);
    return pow(specAngle, shininess);
}

float Blinn_Phong(vec3 lightDir, vec3 rayDir, vec3 normal, float shininess) {
    vec3 H = normalize(lightDir + rayDir);
    float specAngle = max(dot(H, normal), 0.0);
    return pow(specAngle, shininess);
}

float Trowbridge_Reitz_GGX(float NdotH, float roughness) {
    /*
        GGXTR(N,H,α) = α² / π*((N*H)²*(α² + 1)-1)²
    */
    float roughness2 = roughness * roughness;
    float NdotH2 = NdotH * NdotH;

    float nom = roughness2;
    float denom = (NdotH * (roughness2 - 1.0) + 1.0);
    return nom / (denom * denom);
}

float Geometry_Schlick_GGX(float NdotV, float roughness) {
    /*
        SchlickGGX(N,V,k) = N*V/(N*V)*(1 - k) + k
    */
    float denom = NdotV * (1.0 - roughness) + roughness;
    return NdotV / denom;
}

float Geometry_Smith(float NdotV, float NdotL, float roughness) {
    float r = roughness + 1.0;
    roughness = (r * r) / 8.0;

    float ggxV = Geometry_Schlick_GGX(NdotV, roughness);
    float ggxL = Geometry_Schlick_GGX(NdotL, roughness);
    return (ggxV * ggxL) / max((4.0 * NdotL * NdotV), 0.001);
}

vec3 Fresnel_Schlick(float cosTheta, vec3 F0) {
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

// https://www.unrealengine.com/en-US/blog/physically-based-shading-on-mobile?sessionInvalidated=true
vec3 EnvBRDFApprox(vec3 specular, float NdotV, float roughness) {
    const vec4 c0 = vec4(-1.0, -0.0275, -0.572, 0.022);
    const vec4 c1 = vec4(1.0, 0.0425, 1.04, -0.04);
    vec4 r = roughness * c0 + c1;
    float a004 = min(r.x * r.x, exp2(-9.28 * NdotV)) * r.x + r.y;
    vec2 AB = vec2(-1.04, 1.04) * a004 + r.zw;
    return specular * AB.x + AB.y;
}

/*
    Props to LVutner for sharing resources 
    and helping me learn more about Physically 
    Based Rendering!

    https://github.com/LVutner
    https://gist.github.com/LVutner/c07a3cc4fec338e8fe3fa5e598787e47
*/
vec3 BRDF_Lighting(vec3 N, vec3 V, vec3 L, vec3 albedo, float roughness, float F0, vec3 dayTimeColor, vec3 lightmapColor, vec3 shadowmap, vec3 vl) {
    bool is_metal = (F0 * 255.0) > 229.5;
    vec3 Diffuse = is_metal ? vec3(0.0) : albedo;
    vec3 Specular = is_metal ? albedo : vec3(F0);

    float alpha = roughness * roughness;

    vec3 H = normalize(V + L); // Halfway vector
    float NdotL = max(dot(N, L), 0.0);
    float NdotV = max(dot(N, V), 0.0001);
    float NdotH = max(dot(N, H), 0.0);
    float LdotH = max(dot(L, H), 0.0);

    // PBR Lighting
    vec3 SpecularLight = vec3(0.0);
    #if SPECULAR == 1
        float DistributionGGX = Trowbridge_Reitz_GGX(NdotH, roughness); // NDF (Normal Distribution Function)
        vec3 Fresnel = EnvBRDFApprox(Specular, NdotV, roughness); // Fresnel
        // vec3 Fresnel = Fresnel_Schlick(NdotV, Specular);
        // vec3 Fresnel = EnvBRDFApprox(Specular, NdotV, roughness);
        float Visibility = Geometry_Smith(NdotV, NdotL, roughness); // Geometry Smith
        
        SpecularLight = (DistributionGGX * Fresnel * Visibility) * shadowmap;
    #endif
    // Energy conservation
    /*
    vec3 F_NdotL = 1.0 - Fresnel_Schlick(NdotL, SpecularLight);
    vec3 F_NdotV = 1.0 - Fresnel_Schlick(NdotV, SpecularLight);
    */
    
    vec3 DiffuseLight = Diffuse * dayTimeColor;
    vec3 Lighting = ((DiffuseLight + SpecularLight + vl) * (lightmapColor + (NdotL * shadowmap))) * INV_PI;
    return Lighting;
}
