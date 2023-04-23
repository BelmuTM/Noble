/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

/*
                        - CREDITS -
    Thanks Bálint#1673 and Jessie#7257 for their huge help!
*/

#if GI == 1
    vec3 evaluateMicrosurfaceOpaque(vec2 hitPosition, vec3 wi, vec3 wo, Material material) {
        vec4 shadowmap = texture(SHADOWMAP_BUFFER, hitPosition.xy);

        #if SPECULAR == 1
            vec3 specular = computeSpecular(material, wi, wo);
        #else
            vec3 specular = vec3(0.0);
        #endif

        if(material.F0 * maxVal8 > 229.5) {
            return specular * shadowmap.rgb;
        }

        vec3 diffuse = material.albedo * hammonDiffuse(material, wi, wo);

        #if SUBSURFACE_SCATTERING == 1
            diffuse += subsurfaceScatteringApprox(material, wi, wo, shadowmap.a) * float(material.lightmap.y > EPS);
        #endif

        return (diffuse + specular) * shadowmap.rgb;
    }

    vec3 sampleMicrosurfaceOpaquePhase(inout vec3 wr, Material material) {
        mat3 TBN        = constructViewTBN(material.normal);
        vec3 microfacet = TBN * sampleGGXVNDF(-wr * TBN, rand2F(), material.roughness);
        vec3 fresnel    = fresnelDielectricConductor(dot(microfacet, -wr), material.N, material.K);

        float fresnelLuminance          = luminance(fresnel);
        float albedoLuminance           = luminance(material.albedo);
        float specularBounceProbability = fresnelLuminance / (albedoLuminance * (1.0 - fresnelLuminance) + fresnelLuminance);
 
        vec3 phase = vec3(0.0);

        if(specularBounceProbability > randF()) {
            wr    = reflect(wr, microfacet);
            phase = fresnel / specularBounceProbability;
        } else {
            vec3 energyConservationFactor = 1.0 - hemisphericalAlbedo(material.N / vec3(airIOR));

            wr     = generateCosineVector(microfacet, rand2F());
            phase  = (1.0 - fresnel) / (1.0 - specularBounceProbability);
            phase /= energyConservationFactor;
            phase *= (1.0 - fresnelDielectricConductor(dot(microfacet, wr), material.N, material.K));
            phase *= material.albedo * material.ao;
        }
        return phase;
    }

    void pathtrace(inout vec3 radiance, in vec3 screenPosition, inout vec3 outColorDirect, inout vec3 outColorIndirect) {
        vec3 viewPosition = screenToView(screenPosition);

        vec3 directIlluminance = texelFetch(ILLUMINANCE_BUFFER, ivec2(0), 0).rgb;

        for(int i = 0; i < GI_SAMPLES; i++) {

            vec3 rayPosition  = screenPosition; 
            vec3 rayDirection = normalize(viewPosition);
            Material material;

            vec3 throughput = vec3(1.0);
            vec3 estimate   = vec3(0.0);

            for(int j = 0; j < MAX_GI_BOUNCES; j++) {

                /* Russian Roulette */
                if(j > MIN_ROULETTE_BOUNCES) {
                    float roulette = saturate(maxOf(throughput));
                    if(roulette < randF()) { throughput = vec3(0.0); break; }
                    throughput /= roulette;
                }
                
                material = getMaterial(rayPosition.xy);

                vec3 brdf  = evaluateMicrosurfaceOpaque(rayPosition.xy, -rayDirection, shadowVec, material) * directIlluminance;
                vec3 phase = sampleMicrosurfaceOpaquePhase(rayDirection, material);

                brdf += material.albedo * EMISSIVE_INTENSITY * material.emission;
             
                if(dot(material.normal, rayDirection) <= 0.0) continue;
                bool hit = raytrace(depthtex0, screenToView(rayPosition), rayDirection, MAX_GI_STEPS, randF(), rayPosition);

                if(j == 0) {
                    outColorDirect   = brdf;
                    outColorIndirect = phase;
                } else {
                    estimate   += throughput * brdf; 
                    throughput *= phase;
                }

                if(!hit) {
                    #if SKY_CONTRIBUTION == 1
                        // vec2 coords = projectSphere(normalize(viewToScene(rayDirection)));
		                // vec3 sky    = texture(ATMOSPHERE_BUFFER, saturate(coords + randF() * pixelSize)).rgb;

                        estimate += throughput * texture(ILLUMINANCE_BUFFER, rayPosition.xy).rgb * getSkyLightFalloff(material.lightmap.y);
                    #endif
                    break;
                }
            }
            radiance += max0(estimate) * rcp(GI_SAMPLES);
        }
    }
#endif
