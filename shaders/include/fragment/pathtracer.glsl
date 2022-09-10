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
    // Provided by Jessie#7257
    float hemisphericalAlbedo(in float n) {
        float n2  = pow2(n);
        float T_1 = (4.0 * (2.0 * n + 1.0)) / (3.0 * pow2(n + 1.0));
        float T_2 = ((4.0 * pow3(n) * (n2 + 2.0 * n - 1.0)) / (pow2(n2 + 1.0) * (n2 - 1.0))) - 
                ((2.0 * n2 * (n2 + 1.0) * log(n)) / pow2(n2 - 1.0)) +
                ((2.0 * n2 * pow2(n2 - 1.0) * log((n * (n + 1.0)) / (n-  1.0))) / pow3(n2 + 1.0));
        return clamp01(1.0 - 0.5 * (T_1 + T_2));
    }

    vec3 specularBRDF(vec3 N, vec3 V, vec3 L, vec3 fresnel, in float roughness) {
        float NdotV = maxEps(dot(N, V));
        float NdotL = clamp01(dot(N, L));

        return (fresnel * G2SmithGGX(NdotL, NdotV, roughness)) / G1SmithGGX(NdotV, roughness);
    }

    vec3 directBRDF(vec2 hitPos, vec3 V, vec3 L, Material mat) {
        vec3 diffuse  = hammonDiffuse(mat, V, L);
        vec3 specular = SPECULAR == 0 ? vec3(0.0) : computeSpecular(mat.normal, V, L, mat);

        vec4 shadowmap = texture(colortex3, hitPos.xy);

        #if SUBSURFACE_SCATTERING == 1
            diffuse += subsurfaceScatteringApprox(mat, V, L, shadowmap.a) * float(mat.lightmap.y > EPS);
        #endif

        vec3 direct  = mat.albedo * diffuse + specular;
             direct *= shadowmap.rgb * sampleDirectIlluminance();
        return direct;
    }

    vec3 indirectBRDF(vec2 noise, Material mat, inout vec3 rayDir) {
        mat3 TBN        = constructViewTBN(mat.normal);
        vec3 microfacet = TBN * sampleGGXVNDF(-rayDir * TBN, noise, mat.rough);
        vec3 fresnel    = fresnelComplex(dot(microfacet, -rayDir), mat);

        // Specular bounce probability from https://www.shadertoy.com/view/ssc3WH
        float specular     = clamp01(luminance(fresnel));
        float diffuse      = luminance(mat.albedo) * (1.0 - float(mat.F0 * maxVal8 > 229.5)) * (1.0 - specular);
        float specularProb = specular / maxEps(specular + diffuse);
 
        vec3 BRDF = vec3(0.0);
        if(specularProb > randF()) {
            vec3 newDir = reflect(rayDir, microfacet);
            BRDF        = specularBRDF(microfacet, -rayDir, newDir, fresnel, mat.rough) / specularProb;
            rayDir      = newDir;
        } else {
            float matIOR                   = f0ToIOR(mat.F0);
            float energyConservationFactor = 1.0 - hemisphericalAlbedo(matIOR * rcp(airIOR));

            rayDir = generateCosineVector(mat.normal, noise);
            BRDF   = (1.0 - fresnel) / (1.0 - specularProb);
            BRDF  /= energyConservationFactor;
            BRDF  *= (1.0 - fresnelDielectric(dot(mat.normal, rayDir), airIOR, matIOR));
            BRDF  *= mat.albedo * mat.ao;
        }
        return BRDF;
    }

    void pathTrace(inout vec3 radiance, in vec3 screenPos, inout vec3 outColorDirect, inout vec3 outColorIndirect) {
        vec3 viewPos   = screenToView(screenPos);
        vec3 skyRayDir = unprojectSphere(texCoords);

        for(int i = 0; i < GI_SAMPLES; i++) {
            vec3 throughput = vec3(1.0);

            vec3 hitPos = screenPos; 
            vec3 rayDir = normalize(viewPos);
            Material mat;

            for(int j = 0; j < GI_BOUNCES; j++) {
                vec2 noise = vec2(randF(), randF());

                /* Russian Roulette */
                if(j > ROULETTE_MIN_BOUNCES) {
                    float roulette = clamp01(maxOf(throughput));
                    if(roulette < randF()) { throughput = vec3(0.0); break; }
                    throughput /= roulette;
                }
                
                mat            = getMaterial(hitPos.xy);
                mat.lightmap.y = getSkyLightFalloff(mat.lightmap.y);

                vec3 directLighting  = directBRDF(hitPos.xy, -rayDir, shadowVec, mat);
                     directLighting += getBlockLightColor(mat) * mat.emission;
                vec3 indirectBounce  = indirectBRDF(noise, mat, rayDir);
             
                if(dot(mat.normal, rayDir) < 0.0) continue;
                bool hit = raytrace(depthtex0, screenToView(hitPos), rayDir, GI_STEPS, randF(), hitPos);

                if(j == 0) { 
                    outColorDirect   = directLighting;
                    outColorIndirect = indirectBounce;
                } else {
                    radiance   += throughput * directLighting; 
                    throughput *= indirectBounce;
                }

                if(!hit) {
                    #if SKY_CONTRIBUTION == 1
		                vec3 sky = texture(colortex6, hitPos.xy).rgb;
                        radiance += throughput * sky * mat.lightmap.y;
                    #endif
                    break;
                }
            }
        }
        radiance = max0(radiance) * rcp(GI_SAMPLES);
    }
#endif
