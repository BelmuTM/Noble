/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#define EDGE_ATTENUATION_FACTOR 0.15

// Kneemund's Edge Attenuation
float KneemundAttenuation(vec2 pos) {
    return 1.0 - quintic(EDGE_ATTENUATION_FACTOR, 0.0, minOf(pos * (1.0 - pos)));
}

vec3 getHitColor(in vec3 hitPos) {
    #if SSR_REPROJECTION == 1
        hitPos -= getVelocity(hitPos);
        return texture(HISTORY_BUFFER, hitPos.xy).rgb;
    #else
        return texture(DEFERRED_BUFFER, hitPos.xy).rgb;
    #endif
}

vec3 getSkyFallback(vec3 reflected, Material material) {
    #if defined WORLD_OVERWORLD
        vec2 coords = projectSphere(mat3(gbufferModelViewInverse) * reflected);
        vec3 sky    = texture(ATMOSPHERE_BUFFER, clamp01(coords + randF() * pixelSize)).rgb;

        return sky * getSkyLightFalloff(material.lightmap.y);
    #else
        return vec3(0.0);
    #endif
}

//////////////////////////////////////////////////////////
/*------------------ SIMPLE REFLECTIONS ----------------*/
//////////////////////////////////////////////////////////

#if REFLECTIONS_TYPE == 0
    vec3 simpleReflections(vec3 viewPos, Material material) {
        viewPos     += material.normal * 1e-2;
        vec3 viewDir = normalize(viewPos);

        vec3 rayDir   = reflect(viewDir, material.normal); vec3 hitPos;
        float hit     = float(raytrace(depthtex0, viewPos, rayDir, SIMPLE_REFLECT_STEPS, randF(), hitPos));
              hit    *= KneemundAttenuation(hitPos.xy);
        vec3 hitColor = getHitColor(hitPos);

        #if defined SKY_FALLBACK
            vec3 color = mix(getSkyFallback(rayDir, material), hitColor, hit);
        #else
            vec3 color = mix(vec3(0.0), hitColor, hit);
        #endif

        float NdotL   = abs(dot(material.normal, rayDir));
        float NdotV   = dot(material.normal, -viewDir);
        float alphaSq = maxEps(material.roughness * material.roughness);

        vec3  F  = fresnelDielectricConductor(NdotL, material.N, material.K);
        float G1 = G1SmithGGX(NdotV, alphaSq);
        float G2 = G2SmithGGX(NdotL, NdotV, alphaSq);

        return NdotV > 0.0 && NdotL > 0.0 ? color * F : vec3(0.0);
    }
#else

//////////////////////////////////////////////////////////
/*------------------ ROUGH REFLECTIONS -----------------*/
//////////////////////////////////////////////////////////

    vec3 roughReflections(vec3 viewPos, Material material) {
	    vec3 color = vec3(0.0); vec3 hitPos;
        int samples = 0;

        viewPos     += material.normal * 1e-2;
        mat3 TBN     = constructViewTBN(material.normal);
        vec3 viewDir = normalize(viewPos);
        float NdotV  = dot(material.normal, -viewDir);
	
        for(int i = 0; i < ROUGH_SAMPLES; i++) {
            vec3 microfacet = TBN * sampleGGXVNDF(-viewDir * TBN, rand2F(), material.roughness);
		    vec3 rayDir     = reflect(viewDir, microfacet);	
            float NdotL     = abs(dot(material.normal, rayDir));

            if(NdotV > 0.0 && NdotL > 0.0) {
                float hit     = float(raytrace(depthtex0, viewPos, rayDir, ROUGH_REFLECT_STEPS, randF(), hitPos));
                      hit    *= KneemundAttenuation(hitPos.xy);
                vec3 hitColor = getHitColor(hitPos);

                #if defined SKY_FALLBACK
                    hitColor = mix(getSkyFallback(rayDir, material), getHitColor(hitPos), hit);
                #else
                    hitColor = mix(vec3(0.0), getHitColor(hitPos), hit);
                #endif

                float MdotV   = dot(microfacet, -viewDir);
                float alphaSq = maxEps(material.roughness * material.roughness);

                vec3  F  = isEyeInWater == 1 ? vec3(fresnelDielectric(MdotV, 1.329, airIOR)) : fresnelDielectricConductor(MdotV, material.N, material.K);
                float G1 = G1SmithGGX(NdotV, alphaSq);
                float G2 = G2SmithGGX(NdotL, NdotV, alphaSq);

                color += hitColor * ((F * G2) / G1);
                samples++;
            }
	    }
	    return max0(color * rcp(samples));
    }
#endif
