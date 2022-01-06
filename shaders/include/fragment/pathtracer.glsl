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

#if GI == 1
    vec3 specularBRDF(vec3 N, vec3 V, vec3 L, vec3 fresnel, in float roughness) {
        float NdotV = maxEps(dot(N, V));
        float NdotL = maxEps(dot(N, L));

        return fresnel * G2SmithGGX(NdotV, NdotL, roughness) / G1SmithGGX(NdotV, roughness);
    }

    vec3 directBRDF(vec3 N, vec3 V, vec3 L, material mat, vec3 shadowmap, vec3 shadowLightIlluminance) {
        vec3 specular = SPECULAR == 0 ? vec3(0.0) : cookTorranceSpecular(N, V, L, mat);
        vec3 diffuse  = mat.isMetal   ? vec3(0.0) : hammonDiffuse(N, V, L, mat, false);

        return (diffuse + specular) * (shadowmap * maxEps(dot(N, L))) * shadowLightIlluminance;
    }

    vec3 pathTrace(in vec3 screenPos) {
        vec3 radiance = vec3(0.0);
        vec3 viewPos  = screenToView(screenPos);

        vec3 shadowLightIlluminance = vec3(1.0);
        #ifdef WORLD_OVERWORLD
            shadowLightIlluminance = worldTime <= 12750 ? 
              atmosphereTransmittance(atmosRayPos, playerSunDir)  * sunIlluminance
            : atmosphereTransmittance(atmosRayPos, playerMoonDir) * moonIlluminance;
        #endif

        for(int i = 0; i < GI_SAMPLES; i++) {
            vec3 throughput = vec3(1.0);

            vec3 hitPos = screenPos; 
            vec3 rayDir = normalize(viewPos);

            material mat;
            mat3 TBN;

            for(int j = 0; j <= GI_BOUNCES; j++) {
                vec2 noise = uniformAnimatedNoise(vec2(randF(), randF()));

                if(j > 0) {
                    /* Russian Roulette */
                    if(j > ROULETTE_MIN__BOUNCES) {
                        float roulette = clamp01(max(throughput.r, max(throughput.g, throughput.b)));
                        if(roulette < randF()) { break; }
                        throughput /= roulette;
                    }

                    vec3 microfacet = TBN * sampleGGXVNDF(-rayDir * TBN, noise, pow2(mat.rough));
                    vec3 fresnel    = fresnelDielectric(dot(-rayDir, microfacet), F0toIOR(getSpecularColor(mat.F0, mat.albedo)));

                    /* Specular Bounce Probability */
                    float fresnelLum    = luminance(fresnel);
                    float totalLum      = luminance(mat.albedo) * (1.0 - fresnelLum) + fresnelLum;
                    float specularProb  = fresnelLum / totalLum;
 
                    if(specularProb > randF()) {
                        rayDir      = reflect(rayDir, mat.rough <= 0.05 ? mat.normal : microfacet);
                        throughput *= specularBRDF(microfacet, -rayDir, rayDir, fresnel, mat.rough) / specularProb;
                    } else {
                        throughput *= (1.0 - fresnelDielectric(dot(-rayDir, microfacet), F0toIOR(mat.F0))) / (1.0 - specularProb);
                        rayDir      = generateCosineVector(mat.normal, noise);
                        throughput *= mat.albedo;
                    }
                    if(dot(mat.normal, rayDir) < 0.0) { break; }
                }

                if(!raytrace(screenToView(hitPos), rayDir, GI_STEPS, randF(), hitPos)) { break; }
                
                /* Material & Direct Lighting */
                mat = getMaterial(hitPos.xy);
                TBN = constructViewTBN(mat.normal);

                radiance += throughput * mat.albedo * BLOCKLIGHT_MULTIPLIER * mat.emission;

                #ifdef WORLD_OVERWORLD
                    radiance += throughput * directBRDF(mat.normal, -rayDir, shadowDir, mat, texture(colortex3, hitPos.xy).rgb, shadowLightIlluminance);
                #endif
            }
        }
        return max0(radiance) / float(GI_SAMPLES);
    }
#endif
