/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/*
                        - CREDITS -
    Thanks Bálint#1673 and Jessie#7257 for their huge help!
*/

vec3 specularBRDF(float NdotL, vec3 fresnel, in float roughness) {
    float k = roughness + 1.0;
    return fresnel * G_SchlickGGX(NdotL, (k * k) * 0.125);
}

vec3 directBRDF(vec3 N, vec3 V, vec3 L, material mat, vec3 shadowmap) {
    float NdotV = max(EPS, dot(N, V));
    float NdotL = max(0.0, dot(N, L));

    vec3 specular = cookTorranceSpecular(N, V, L, mat);
    vec3 diffuse = mat.isMetal ? vec3(0.0) : hammonDiffuse(N, V, L, mat);

    return (diffuse + specular) * (NdotL * shadowmap);
}

vec3 pathTrace(in vec3 screenPos) {
    vec3 viewPos         = screenToView(screenPos); 
    vec3 radiance        = vec3(0.0);
    vec3 sunIlluminance  = SUN_ILLUMINANCE * atmosphereTransmittance(atmosRayPos, worldSunDir);
    vec3 moonIlluminance = MOON_ILLUMINANCE * atmosphereTransmittance(atmosRayPos, worldMoonDir);

    for(int i = 0; i < GI_SAMPLES; i++) {
        vec3 hitPos = screenPos; 
        vec3 rayDir = normalize(viewPos);
        vec3 prevDir;

        vec3 throughput = vec3(1.0);
        for(int j = 0; j <= GI_BOUNCES; j++) {
            prevDir = rayDir;
            vec3 viewHitPos = screenToView(hitPos);

            vec2 noise = uniformAnimatedNoise(hash23(vec3(gl_FragCoord.xy, frameTimeCounter)));

            /* Russian Roulette */
            if(j > 3) {
                float roulette = max(throughput.r, max(throughput.g, throughput.b));
                if(roulette < noise.x) { break; }
                throughput /= roulette;
            }
            vec3 H = normalize(-prevDir + rayDir);
            float HdotV = max(EPS, dot(H, -prevDir));

            /* Material Parameters */
            material mat = getMaterial(hitPos.xy);
            vec3 normal = normalize(mat.normal);
            mat3 TBN = constructViewTBN(normal);

            /* Specular Bounce Probability */
            vec3 fresnel = cookTorranceFresnel(HdotV, mat.F0, getSpecularColor(mat.F0, mat.albedo), mat.isMetal);
            float fresnelLum = luma(fresnel);
            float diffuseLum = fresnelLum / (fresnelLum + luma(mat.albedo) * (1.0 - float(mat.isMetal)) * (1.0 - fresnelLum));

            float specularProbability = fresnelLum / max(EPS, fresnelLum + diffuseLum);
            bool specularBounce = specularProbability > rand(gl_FragCoord.xy + frameTimeCounter);

            vec3 microfacet = sampleGGXVNDF(-prevDir * TBN, noise, mat.rough * mat.rough);
            rayDir = specularBounce ? reflect(prevDir, TBN * microfacet) : normalize(normal + generateUnitVector(noise));
            float NdotL = max(EPS, dot(normal, rayDir));

            radiance += throughput * mat.albedo * mat.emission;
            radiance += throughput * directBRDF(normal, -prevDir, shadowDir, mat, texture(colortex9, hitPos.xy).rgb) * (sunIlluminance + moonIlluminance);

            if(!raytrace(viewHitPos, rayDir, GI_STEPS, uniformNoise(i, blueNoise).x, hitPos)) { break; }

            float HdotL = max(0.0, dot(normalize(-prevDir + rayDir), rayDir));
            vec3 specularFresnel = cookTorranceFresnel(HdotL, mat.F0, getSpecularColor(mat.F0, mat.albedo), mat.isMetal);

            if(specularBounce) {
                throughput *= specularBRDF(NdotL, specularFresnel, mat.rough) / specularProbability;
            } else {
                throughput *= (1.0 - fresnelDielectric(NdotL, F0toIOR(mat.F0))) / (1.0 - specularProbability);
                throughput *= hammonDiffuse(normal, -prevDir, rayDir, mat) / (NdotL * INV_PI);
            }
        }
    }
    return max(vec3(0.0), radiance / float(GI_SAMPLES));
}

/*
-------------------------------
|        OLD PTGI CODE        |
-------------------------------

vec3 PTGIBRDF(in vec3 viewDir, in vec2 screenPos, in vec3 sampleDir, in mat3 TBN, in vec3 normal, in vec2 noise, out vec3 mat.albedo) {
    float F0 = texture(colortex2, screenPos).g;
    bool mat.isMetal = F0 * 255.0 > 229.5;
    float roughness = texture(colortex2, screenPos).r;

    vec3 microfacet = sampleGGXVNDF(-viewDir * TBN, noise, roughness);
    vec3 reflected = reflect(viewDir, TBN * microfacet);

    vec3 H = normalize(viewDir + reflected);
    float NdotD = max(EPS, dot(normal, sampleDir));
    float NdotL = max(EPS, dot(normal, reflected)); 
    float NdotV = max(EPS, dot(normal, viewDir));
    float NdotH = max(EPS, dot(normal, H));
    float HdotL = max(EPS, dot(H, reflected));

    mat.albedo = mat.isMetal ? vec3(0.0) : texture(colortex4, screenPos).rgb;
    vec3 specular = cookTorranceSpecular(NdotH, HdotL, NdotV, NdotL, roughness, F0, mat.albedo, mat.isMetal);
    // vec3 diffuse = orenNayarDiffuse(normal, viewDir, sampleDir, NdotD, NdotV, roughness * roughness, mat.albedo) / (NdotD * INV_PI);

    vec3 fresnel = cookTorranceFresnel(NdotD, F0, mat.albedo, mat.isMetal);
    mat.albedo *= 1.0 - fresnel;
    return mat.albedo + specular;
}

vec3 computePTGI(in vec3 screenPos) {
    vec3 hitPos = screenPos; 
    vec3 viewPos = screenToView(screenPos); 
    vec3 viewDir = -normalize(viewPos);

    vec3 throughput = vec3(1.0);
    vec3 radiance = vec3(0.0);
    vec3 mat.albedo;

    for(int i = 0; i < GI_SAMPLES; i++) {
        for(int j = 0; j < GI_BOUNCES; j++) {
            vec2 noise = uniformAnimatedNoise(animBlueNoise.xy);

            vec3 normal = normalize(decodeNormal(texture(colortex1, hitPos.xy).xy));
            mat3 TBN = constructViewTBN(normal);
            hitPos = screenToView(hitPos) + normal * EPS;
        
            vec3 sampleDir = TBN * generateUnitVector(noise);
            if(!raytrace(hitPos, sampleDir, GI_STEPS, uniformNoise(j, blueNoise).x, hitPos)) continue;

            vec3 BRDF = PTGIBRDF(viewDir, hitPos.xy, sampleDir, TBN, normal, noise, mat.albedo);

            radiance += throughput * mat.albedo * (texture(colortex1, hitPos.xy).z * EMISSION_INTENSITY);
            throughput *= BRDF;
            radiance += throughput * texture(colortex9, hitPos.xy).rgb * viewPosSkyColor(viewPos) * SUN_ILLUMINANCE;
        }
    }
    radiance /= GI_SAMPLES;
    return radiance;
}
*/
