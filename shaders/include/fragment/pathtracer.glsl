/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

/*
                        - CREDITS -
    Thanks Bálint#1673 and Jessie#7257 for their huge help!
*/

#if GI == 1
    vec3 evaluateMicrosurfaceBRDF(vec2 hitPos, vec3 wi, vec3 wo, Material material) {
        vec4 shadowmap = texture(colortex3, hitPos.xy);

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

    vec3 sampleMicrosurfaceBRDFPhase(inout vec3 wr, Material material) {
        mat3 TBN        = constructViewTBN(material.normal);
        vec3 microfacet = TBN * sampleGGXVNDF(-wr * TBN, rand2F(), material.roughness);
        vec3 fresnel    = fresnelDielectricConductor(dot(microfacet, -wr), material.N, material.K);

        float fresnelLuminance          = luminance(fresnel);
        float albedoLuminance           = luminance(material.albedo);
        float specularBounceProbability = fresnelLuminance / (albedoLuminance * (1.0 - fresnelLuminance) + fresnelLuminance);
 
        vec3 brdf = vec3(0.0);

        if(specularBounceProbability > randF()) {
            wr   = reflect(wr, microfacet);
            brdf = fresnel / specularBounceProbability;
        } else {
            vec3 energyConservationFactor = 1.0 - hemisphericalAlbedo(material.N / vec3(airIOR));

            wr    = generateCosineVector(microfacet, rand2F());
            brdf  = (1.0 - fresnel) / (1.0 - specularBounceProbability);
            brdf /= energyConservationFactor;
            brdf *= (1.0 - fresnelDielectricConductor(dot(microfacet, wr), material.N, material.K));
            brdf *= material.albedo * material.ao;
        }
        return brdf;
    }

    void pathtrace(inout vec3 radiance, in vec3 screenPosition, inout vec3 outColorDirect, inout vec3 outColorIndirect) {
        vec3 viewPosition = screenToView(screenPosition);

        vec3 directIlluminance = texelFetch(colortex6, ivec2(0), 0).rgb;

        for(int i = 0; i < GI_SAMPLES; i++) {

            vec3 rayPosition  = screenPosition; 
            vec3 rayDirection = normalize(viewPosition);
            Material material;

            vec3 samplethroughput = vec3(1.0);
            vec3 sampleRadiance   = vec3(0.0);

            for(int j = 0; j < MAX_GI_BOUNCES; j++) {

                /* Russian Roulette */
                if(j > MIN_ROULETTE_BOUNCES) {
                    float roulette = clamp01(maxOf(samplethroughput));
                    if(roulette < randF()) { samplethroughput = vec3(0.0); break; }
                    samplethroughput /= roulette;
                }
                
                material = getMaterial(rayPosition.xy);

                vec3 estimate = evaluateMicrosurfaceBRDF(rayPosition.xy, -rayDirection, shadowVec, material) * directIlluminance;
                vec3 phase    = sampleMicrosurfaceBRDFPhase(rayDirection, material);

                estimate += material.albedo * EMISSIVE_INTENSITY * material.emission;
             
                if(dot(material.normal, rayDirection) <= 0.0) continue;
                bool hit = raytrace(depthtex0, screenToView(rayPosition), rayDirection, MAX_GI_STEPS, randF(), rayPosition);

                if(j == 0) {
                    outColorDirect   = estimate;
                    outColorIndirect = phase;
                } else {
                    sampleRadiance   += samplethroughput * estimate; 
                    samplethroughput *= phase;
                }

                if(!hit) {
                    #if SKY_CONTRIBUTION == 1
                        // vec2 coords = projectSphere(normalize(viewToScene(rayDirection)));
		                // vec3 sky    = texture(colortex12, clamp01(coords + randF() * pixelSize)).rgb;

                        sampleRadiance += samplethroughput * texture(colortex6, rayPosition.xy).rgb * RCP_PI * getSkyLightFalloff(material.lightmap.y);
                    #endif
                    break;
                }
            }
            radiance += max0(sampleRadiance) * rcp(GI_SAMPLES);
        }
    }
#endif
