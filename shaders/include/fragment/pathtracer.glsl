/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
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

        return (fresnel * G2SmithGGX(NdotL, NdotV, roughness)) / G1SmithGGX(NdotV, roughness);
    }

    vec3 directBRDF(vec2 hitPos, vec3 V, vec3 L, Material mat, vec3 shadowmap) {
        vec3 diffuse     = hammonDiffuse(mat.normal, V, L, mat, false);
        vec3 specular    = SPECULAR == 0 ? vec3(0.0) : computeSpecular(mat.normal, V, L, mat);
        vec3 directLight = sampleDirectIlluminance();

        #if SUBSURFACE_SCATTERING == 1
            diffuse = mix(diffuse, disneySubsurface(mat.normal, V, L, mat) * mat.albedo, mat.subsurface);
        #endif

        vec3 direct  = (mat.albedo * diffuse) + specular;
             direct *= (shadowmap * directLight);
        return direct;
    }

    vec3 indirectBRDF(vec2 noise, Material mat, inout vec3 rayDir) {
        mat3 TBN        = constructViewTBN(mat.normal);
        vec3 microfacet = TBN * sampleGGXVNDF(-rayDir * TBN, noise, mat.rough);
        vec3 fresnel    = fresnelComplex(dot(-rayDir, microfacet), mat);

        float fresnelLum   = luminance(fresnel);
        float totalLum     = luminance(mat.albedo) * (1.0 - fresnelLum) + fresnelLum;
        float specularProb = fresnelLum / totalLum;
 
        vec3 BRDF = vec3(0.0);
        if(specularProb > randF()) {
            vec3 newDir = reflect(rayDir, microfacet);
            BRDF        = specularBRDF(microfacet, -rayDir, newDir, fresnel, mat.rough) / specularProb;
            rayDir      = newDir;
        } else {
            BRDF   = (1.0 - fresnel) / (1.0 - specularProb) * mat.albedo;
            rayDir = generateCosineVector(mat.normal, noise);
        }
        return BRDF;
    }

    void pathTrace(inout vec3 radiance, in vec3 screenPos, inout vec3 outColorDirect, inout vec3 outColorIndirect) {
        vec3 viewPos   = screenToView(screenPos);
        vec3 skyRayDir = unprojectSphere(texCoords);

        int samples = 0;
        for(int i = 0; i < GI_SAMPLES; i++, samples++) {
            vec3 throughput = vec3(1.0);

            vec3 hitPos = screenPos; 
            vec3 rayDir = normalize(viewPos);
            Material mat;

            for(int j = 0; j <= GI_BOUNCES; j++) {
                vec2 noise = vec2(randF(), randF());

                /* Russian Roulette */
                if(j > ROULETTE_MIN_BOUNCES) {
                    float roulette = clamp01(max(throughput.r, max(throughput.g, throughput.b)));
                    if(roulette < randF()) { throughput = vec3(0.0); break; }
                    throughput /= roulette;
                }
                
                mat = getMaterial(hitPos.xy);

                vec3 directLighting  = directBRDF(hitPos.xy, -rayDir, shadowDir, mat, texture(colortex3, hitPos.xy).rgb);
                     directLighting += getBlockLightIntensity(mat) * mat.emission;
                vec3 indirectBounce  = indirectBRDF(noise, mat, rayDir);
             
                if(dot(mat.normal, rayDir) < 0.0) { break; }
                bool hit = raytrace(screenToView(hitPos), rayDir, GI_STEPS, randF(), hitPos);

                if(j == 0) { 
                    outColorDirect   = directLighting;
                    outColorIndirect = indirectBounce;
                } else {
                    radiance   += throughput * directLighting; 
                    throughput *= indirectBounce;
                }

                if(!hit) {
                    #if SKY_CONTRIBUTION == 1
                        vec3 skyHitPos;
                        raytrace(screenToView(hitPos), skyRayDir, int(GI_STEPS * 0.3), randF(), skyHitPos);

                        if(isSky(skyHitPos.xy)) {
                            radiance += throughput * texture(colortex0, skyHitPos.xy).rgb * INV_PI;
                        }
                    #endif
                    break;
                }
            }
        }
        radiance = max0(radiance) / float(samples);
    }
#endif
