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

vec3 specularBRDF(vec3 N, vec3 L, vec3 fresnel, in float roughness) {
    float NdotL = max(EPS, dot(N, L));
    float k = roughness + 1.0;
    return fresnel * G_SchlickGGX(NdotL, (k * k) * 0.125);
}

vec3 directBRDF(vec3 N, vec3 V, vec3 L, vec2 params, vec3 albedo, vec3 shadowmap, bool isMetal) {
    float alpha = params.r * params.r;
    float NdotV = max(EPS, dot(N, V));
    float NdotL = max(EPS, dot(N, L));

    vec3 specular = cookTorranceSpecular(N, V, L, params.r, params.g, albedo, isMetal);
    vec3 diffuse = vec3(0.0);

    if(!isMetal) { 
        diffuse = hammonDiffuse(N, V, L, alpha, albedo);

        float energyConservationFactor = 1.0 - (4.0 * sqrt(params.g) + 5.0 * params.g * params.g) * 0.11111111;
        diffuse *= 1.0 - cookTorranceFresnel(NdotV, params.g, getSpecularColor(params.g, albedo), isMetal);
        diffuse /= energyConservationFactor;
    }
    return (diffuse + specular) * (NdotL * shadowmap);
}

vec3 pathTrace(in vec3 screenPos) {
    vec3 viewPos = screenToView(screenPos); 
    vec3 radiance      = vec3(0.0);
    vec3 sunIlluminance  = SUN_ILLUMINANCE * atmosphereTransmittance(atmosRayPos, worldSunDir);
    vec3 moonIlluminance = MOON_ILLUMINANCE * atmosphereTransmittance(atmosRayPos, worldMoonDir);

    for(int i = 0; i < GI_SAMPLES; i++) {
        vec3 hitPos = screenPos; 
        vec3 rayDir = normalize(viewPos);
        vec3 prevDir;

        vec3 throughput = vec3(1.0);
        for(int j = 0; j <= GI_BOUNCES; j++) {
            prevDir = rayDir;
            vec2 noise = uniformAnimatedNoise(hash23(vec3(gl_FragCoord.xy, frameTimeCounter)));

            /* Russian Roulette */
            if(j > 3) {
                float roulette = max(throughput.r, max(throughput.g, throughput.b));
                if(roulette < noise.x) { break; }
                throughput /= roulette;
            }

            /* Material Parameters and Emitted Light */
            vec2 params = texture(colortex2, hitPos.xy).rg; // R = roughness | G = F0
            bool isMetal = params.g * 255.0 > 229.5;

            vec3 H = normalize(-prevDir + rayDir);
            float HdotV = max(EPS, dot(H, -prevDir));

            vec3 normal = normalize(decodeNormal(texture(colortex1, hitPos.xy).xy));
            mat3 TBN = getTBN(normal);

            vec3 albedo = texture(colortex0, hitPos.xy).rgb;
            radiance += throughput * albedo * texture(colortex1, hitPos.xy).z;
            radiance += throughput * directBRDF(normal, -prevDir, shadowDir, params, albedo, texture(colortex9, hitPos.xy).rgb, isMetal) * (sunIlluminance + moonIlluminance);

            /* Specular Bounce Probability */
            vec3 fresnel = cookTorranceFresnel(HdotV, params.g, getSpecularColor(params.g, albedo), isMetal);
            float fresnelLum = clamp01(luma(fresnel));
            float diffuseLum = fresnelLum / (fresnelLum + luma(albedo) * (1.0 - float(isMetal)) * (1.0 - fresnelLum));

            float specBounceProbability = fresnelLum / max(EPS, fresnelLum + diffuseLum);
            bool specularBounce = specBounceProbability > rand(gl_FragCoord.xy + frameTimeCounter);

            vec3 microfacet = normal;
            if(specularBounce) {
                if(params.r > 1e-3) { microfacet = sampleGGXVNDF(-prevDir * TBN, noise, params.r * params.r); }
                rayDir = reflect(prevDir, TBN * microfacet);
            } else {
                rayDir = TBN * cosineWeightedHemisphereDirection(noise);
            }

            vec3 viewHitPos = screenToView(hitPos) + normal * 1e-3;
            if(!raytrace(viewHitPos, rayDir, GI_STEPS, uniformNoise(i, blueNoise).x, hitPos)) { break; }

            if(specularBounce) {
                throughput /= specBounceProbability;

                float HdotL = max(EPS, dot(normalize(-prevDir + rayDir), rayDir));
                vec3 specularFresnel = cookTorranceFresnel(HdotL, params.g, getSpecularColor(params.g, albedo), isMetal);

                throughput *= specularBRDF(microfacet, rayDir, specularFresnel, params.r);
            } else {
                throughput /= 1.0 - specBounceProbability;
                throughput *= hammonDiffuse(normal, -prevDir, rayDir, params.r * params.r, albedo) / (max(EPS, dot(normal, rayDir)) * INV_PI);
            }
        }
    }
    radiance /= GI_SAMPLES;
    return max(vec3(0.0), radiance);
}

/*
-------------------------------
|        OLD PTGI CODE        |
-------------------------------

vec3 PTGIBRDF(in vec3 viewDir, in vec2 screenPos, in vec3 sampleDir, in mat3 TBN, in vec3 normal, in vec2 noise, out vec3 albedo) {
    float F0 = texture(colortex2, screenPos).g;
    bool isMetal = F0 * 255.0 > 229.5;
    float roughness = texture(colortex2, screenPos).r;

    vec3 microfacet = sampleGGXVNDF(-viewDir * TBN, noise, roughness);
    vec3 reflected = reflect(viewDir, TBN * microfacet);

    vec3 H = normalize(viewDir + reflected);
    float NdotD = max(EPS, dot(normal, sampleDir));
    float NdotL = max(EPS, dot(normal, reflected)); 
    float NdotV = max(EPS, dot(normal, viewDir));
    float NdotH = max(EPS, dot(normal, H));
    float HdotL = max(EPS, dot(H, reflected));

    albedo = isMetal ? vec3(0.0) : texture(colortex4, screenPos).rgb;
    vec3 specular = cookTorranceSpecular(NdotH, HdotL, NdotV, NdotL, roughness, F0, albedo, isMetal);
    // vec3 diffuse = orenNayarDiffuse(normal, viewDir, sampleDir, NdotD, NdotV, roughness * roughness, albedo) / (NdotD * INV_PI);

    vec3 fresnel = cookTorranceFresnel(NdotD, F0, albedo, isMetal);
    albedo *= 1.0 - fresnel;
    return albedo + specular;
}

vec3 computePTGI(in vec3 screenPos) {
    vec3 hitPos = screenPos; 
    vec3 viewPos = screenToView(screenPos); 
    vec3 viewDir = -normalize(viewPos);

    vec3 throughput = vec3(1.0);
    vec3 radiance = vec3(0.0);
    vec3 albedo;

    for(int i = 0; i < GI_SAMPLES; i++) {
        for(int j = 0; j < GI_BOUNCES; j++) {
            vec2 noise = uniformAnimatedNoise(animBlueNoise.xy);

            vec3 normal = normalize(decodeNormal(texture(colortex1, hitPos.xy).xy));
            mat3 TBN = getTBN(normal);
            hitPos = screenToView(hitPos) + normal * EPS;
        
            vec3 sampleDir = TBN * cosineWeightedHemisphereDirection(noise);
            if(!raytrace(hitPos, sampleDir, GI_STEPS, uniformNoise(j, blueNoise).x, hitPos)) continue;

            vec3 BRDF = PTGIBRDF(viewDir, hitPos.xy, sampleDir, TBN, normal, noise, albedo);

            radiance += throughput * albedo * (texture(colortex1, hitPos.xy).z * EMISSION_INTENSITY);
            throughput *= BRDF;
            radiance += throughput * texture(colortex9, hitPos.xy).rgb * viewPosSkyColor(viewPos) * SUN_ILLUMINANCE;
        }
    }
    radiance /= GI_SAMPLES;
    return radiance;
}
*/
