/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

/*
    [Credits]:
        Bálint (https://github.com/BalintCsala)
        Jessie (https://github.com/Jessie-LC)
        Thanks to them for helping me understand the basics of path tracing when I was beginning
*/

vec3 evaluateMicrosurfaceOpaque(vec2 hitPosition, vec3 wi, vec3 wo, Material material, vec3 directIlluminance) {
    vec4 shadowmap = texture(SHADOWMAP_BUFFER, hitPosition.xy);
    vec3 diffuse   = hammonDiffuse(material, wi, wo);

    #if SUBSURFACE_SCATTERING == 1
        diffuse += subsurfaceScatteringApprox(material, wi, wo, shadowmap.a) * float(material.lightmap.y > EPS);
    #endif

    return clamp16(material.albedo * diffuse * shadowmap.rgb * directIlluminance);
}

vec3 sampleMicrosurfaceOpaquePhase(inout vec3 wr, Material material) {
    mat3 tbn        = constructViewTBN(material.normal);
    vec3 microfacet = tbn * sampleGGXVNDF(-wr * tbn, rand2F(), material.roughness);
    vec3 fresnel    = fresnelDielectricConductor(dot(microfacet, -wr), material.N, material.K);

    wr = generateCosineVector(microfacet, rand2F());

    vec3 energyConservationFactor = 1.0 - hemisphericalAlbedo(material.N / vec3(airIOR));

    vec3 phase = vec3(0.0);
    phase  = 1.0 - fresnel;
    phase /= energyConservationFactor;
    phase *= material.albedo * material.ao;
    phase *= fresnelDielectricDielectric_T(dot(microfacet, wr), vec3(airIOR), material.N);
    
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

            int steps = MAX_GI_STEPS;

            /* Russian Roulette */
            if(j > MIN_ROULETTE_BOUNCES) {
                float roulette = saturate(maxOf(throughput));
                if(roulette < randF()) { throughput = vec3(0.0); break; }
                throughput /= roulette;
            }
                
            material = getMaterial(rayPosition.xy);

            vec3 brdf  = evaluateMicrosurfaceOpaque(rayPosition.xy, -rayDirection, shadowVec, material, directIlluminance);
            vec3 phase = sampleMicrosurfaceOpaquePhase(rayDirection, material);

            brdf += material.albedo * EMISSIVE_INTENSITY * material.emission;
             
            bool hit = raytrace(depthtex0, screenToView(rayPosition), rayDirection, steps, randF(), 1.0, rayPosition);

            if(j == 0) {
                outColorDirect   = brdf;
                outColorIndirect = phase;
            } else {
                estimate   += throughput * brdf; 
                throughput *= phase;
            }

            if(!hit) {
                #if defined WORLD_OVERWORLD && SKY_CONTRIBUTION == 1
                    estimate += throughput * texture(ATMOSPHERE_BUFFER, projectSphere(rayPosition)).rgb * RCP_PI * getSkylightFalloff(material.lightmap.y);
                #endif
                break;
            }

            if(dot(material.normal, rayDirection) <= 0.0) break;
        }
        radiance += max0(estimate) * rcp(GI_SAMPLES);
    }
}
