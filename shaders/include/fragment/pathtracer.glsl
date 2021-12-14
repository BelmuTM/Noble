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
    vec3 specularBRDF(float NdotL, vec3 fresnel, in float roughness) {
        float k = roughness + 1.0;
        return fresnel * geometrySchlickGGX(NdotL, (k * k) * 0.125);
    }

    vec3 directBRDF(vec3 N, vec3 V, vec3 L, material mat, vec3 shadowmap, vec3 shadowLightIlluminance) {
        vec3 specular = SPECULAR == 0 ? vec3(0.0) : cookTorranceSpecular(N, V, L, mat);
        vec3 diffuse  = mat.isMetal   ? vec3(0.0) : hammonDiffuse(N, V, L, mat, true);

        return (diffuse + specular) * shadowmap * shadowLightIlluminance;
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
            vec3 prevDir;
            mat3 TBN;

            for(int j = 0; j < GI_BOUNCES + 1; j++) {
                vec2 noise = uniformAnimatedNoise(vec2(randF(rngState), randF(rngState)));
                prevDir    = rayDir;

                if(j > 0) {
                    /* Russian Roulette */
                    float roulette = clamp01(max(throughput.r, max(throughput.g, throughput.b)));
                    if(roulette < randF(rngState)) { break; }
                    throughput /= roulette;

                    float HdotV     = maxEps(dot(normalize(-prevDir + rayDir), -prevDir));
                    vec3 microfacet = TBN * sampleGGXVNDF(-prevDir * TBN, noise, pow2(mat.rough));
                    vec3 fresnel    = specularFresnel(dot(-rayDir, microfacet), getSpecularColor(mat.F0, mat.albedo), mat.isMetal);

                    /* Specular Bounce Probability */
                    float fresnelLum    = luminance(fresnel);
                    float totalLum      = luminance(mat.albedo) * (1.0 - fresnelLum) + fresnelLum;
                    float specularProb  = fresnelLum / totalLum;
                    bool specularBounce = specularProb > randF(rngState);

                    if(specularBounce) {
                        throughput *= fresnel / specularProb;
                        rayDir      = reflect(prevDir, microfacet);
                    } else {
                        throughput *= (1.0 - fresnel) / (1.0 - specularProb);
                        rayDir      = generateCosineVector(mat.normal, noise);
                        throughput *= mat.albedo;
                        // throughput *= hammonDiffuse(mat.normal, -prevDir, rayDir, mat, false) * (clamp01(dot(mat.normal, rayDir)) * INV_PI);
                    }
                    if(dot(mat.normal, rayDir) <= 0.0) { break; }
                }

                if(!raytrace(screenToView(hitPos), rayDir, GI_STEPS, randF(rngState), hitPos)) { break; }
                
                /* Material & Direct Lighting */
                mat        = getMaterial(hitPos.xy);
                mat.albedo = texture(colortex4, hitPos.xy).rgb;
                TBN        = constructViewTBN(mat.normal);

                radiance += throughput * mat.albedo * BLOCKLIGHT_MULTIPLIER * mat.emission;

                #ifdef WORLD_OVERWORLD
                    radiance += throughput * directBRDF(mat.normal, -prevDir, shadowDir, mat, texture(colortex9, hitPos.xy).rgb, shadowLightIlluminance);
                #endif
            }
        }
        return max0(radiance) / GI_SAMPLES;
    }
#endif
