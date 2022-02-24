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
        float NdotL = dot(N, L);

        return fresnel * G2SmithGGX(NdotV, NdotL, roughness) / G1SmithGGX(NdotV, roughness);
    }

    vec3 directBRDF(vec2 hitPos, vec3 N, vec3 V, vec3 L, Material mat, vec3 shadowmap) {
        vec3 specular = SPECULAR == 0 ? vec3(0.0) : cookTorranceSpecular(N, V, L, mat);

        vec3 diffuse = vec3(0.0);
        #if SUBSURFACE_SCATTERING == 1
            float SSS = disneySubsurface(N, V, L, mat);
            diffuse   = mat.isMetal ? vec3(0.0) : mix(hammonDiffuse(N, V, L, mat, false), SSS * mat.albedo, mat.subsurface * float(!isSky(hitPos)));
        #else
            diffuse = mat.isMetal ? vec3(0.0) : hammonDiffuse(N, V, L, mat, false);
        #endif

        #ifdef WORLD_OVERWORLD
            return (diffuse + specular) * (shadowLightTransmittance() * shadowmap);
        #else
            return (diffuse + specular) * shadowmap;
        #endif
    }

    void pathTrace(inout vec3 radiance, in vec3 screenPos) {
        vec3 viewPos   = screenToView(screenPos);
        vec3 skyRayDir = unprojectSphere(texCoords);

        for(int i = 0; i < GI_SAMPLES; i++) {
            vec3 throughput = vec3(1.0);

            vec3 hitPos = screenPos; 
            vec3 rayDir = normalize(viewPos);

            Material mat;
            mat3 TBN;

            for(int j = 0; j <= GI_BOUNCES; j++) {
                vec2 noise = uniformAnimatedNoise(vec2(randF(), randF()));

                /* Russian Roulette */
                if(j > ROULETTE_MIN_BOUNCES) {
                    float roulette = clamp01(max(throughput.r, max(throughput.g, throughput.b)));
                    if(roulette < randF()) { throughput = vec3(0.0); break; }
                    throughput /= roulette;
                }
                
                /* Material & Direct Lighting */
                mat = getMaterial(hitPos.xy);
                TBN = constructViewTBN(mat.normal);

                radiance += throughput * mat.albedo * BLOCKLIGHT_MULTIPLIER * mat.emission;

                #ifdef WORLD_OVERWORLD
                    radiance += throughput * directBRDF(hitPos.xy, mat.normal, -rayDir, shadowDir, mat, texture(colortex3, hitPos.xy).rgb);
                #endif

                vec3 microfacet = TBN * sampleGGXVNDF(-rayDir * TBN, noise, pow2(mat.rough));
                vec3 fresnel    = BRDFFresnel(dot(-rayDir, microfacet), mat);

                /* Specular Bounce Probability */
                float fresnelLum    = luminance(fresnel);
                float totalLum      = luminance(mat.albedo) * (1.0 - fresnelLum) + fresnelLum;
                float specularProb  = fresnelLum / totalLum;
 
                if(specularProb > randF()) {
                    rayDir      = reflect(rayDir, microfacet);
                    throughput *= specularBRDF(microfacet, -rayDir, rayDir, fresnel, mat.rough) / specularProb;
                } else {
                    throughput *= (1.0 - fresnelDieletricConductor(vec3(F0toIOR(mat.F0)), vec3(0.0), dot(-rayDir, microfacet))) / (1.0 - specularProb);
                    rayDir      = generateCosineVector(mat.normal, noise);
                    throughput *= mat.albedo;
                }
                if(dot(mat.normal, rayDir) < 0.0) { break; }

                bool hit = raytrace(screenToView(hitPos), rayDir, GI_STEPS, randF(), hitPos);

                if(!hit) {
                    #if SKY_CONTRIBUTION == 1
                        vec3 skyHitPos;
                        raytrace(screenToView(hitPos), skyRayDir, int(GI_STEPS * 0.3), randF(), skyHitPos);

                        if(isSky(skyHitPos.xy)) {
                            radiance += throughput * texture(colortex7, skyHitPos.xy).rgb * INV_PI;
                        }
                    #endif
                    break;
                 }
            }
        }
        radiance = max0(radiance) / float(GI_SAMPLES);
    }
#endif
