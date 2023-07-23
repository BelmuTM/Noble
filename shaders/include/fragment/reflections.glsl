/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#define EDGE_ATTENUATION_FACTOR (0.15 * RENDER_SCALE)

// Kneemund's Edge Attenuation
float kneemundAttenuation(vec2 pos) {
    return 1.0 - quintic(EDGE_ATTENUATION_FACTOR, 0.0, minOf(pos * (1.0 - pos)));
}

vec3 getHitColor(vec2 hitCoords) {
    #if SSR_REPROJECTION == 1
        return texture(HISTORY_BUFFER, hitCoords).rgb;
    #else
        return texture(DEFERRED_BUFFER, hitCoords).rgb;
    #endif
}

vec3 getSkyFallback(vec2 hitCoords, vec3 reflected, Material material) {
    #if defined WORLD_OVERWORLD || defined WORLD_END
        vec2 coords     = projectSphere(mat3(gbufferModelViewInverse) * reflected);
        vec3 atmosphere = texture(ATMOSPHERE_BUFFER, saturate(coords + randF() * pixelSize)).rgb;

        vec4 clouds = vec4(0.0, 0.0, 0.0, 1.0);
        #if defined WORLD_OVERWORLD
		    #if CLOUDS_LAYER0_ENABLED == 1 || CLOUDS_LAYER1_ENABLED == 1
                if(saturate(hitCoords) == hitCoords) {
			        clouds = texture(CLOUDS_BUFFER, hitCoords * RENDER_SCALE);
                }
		    #endif
        #endif

        return max0((atmosphere * clouds.a + clouds.rgb) * getSkylightFalloff(material.lightmap.y));
    #else
        return vec3(0.0);
    #endif
}

//////////////////////////////////////////////////////////
/*------------------ SMOOTH REFLECTIONS ----------------*/
//////////////////////////////////////////////////////////

#if REFLECTIONS_TYPE == 0
    vec3 computeSmoothReflections(vec3 viewPosition, Material material) {
        viewPosition += material.normal * 1e-2;

        vec3 viewDirection = normalize(viewPosition);
        vec3 rayDirection  = reflect(viewDirection, material.normal); 
        vec3 hitPosition   = vec3(0.0);

        float hit  = float(raytrace(depthtex0, viewPosition, rayDirection, SMOOTH_REFLECTIONS_STEPS, randF(), hitPosition));
              hit *= kneemundAttenuation(hitPosition.xy);

        float NdotL   = abs(dot(material.normal, rayDirection));
        float NdotV   = dot(material.normal, -viewDirection);
        float alphaSq = maxEps(material.roughness * material.roughness);

        vec3  F  = fresnelDielectricConductor(NdotL, material.N, material.K);
        float G1 = G1SmithGGX(NdotV, alphaSq);
        float G2 = G2SmithGGX(NdotL, NdotV, alphaSq);

        #if defined SKY_FALLBACK
            vec3 sampledColor = mix(getSkyFallback(hitPosition.xy, rayDirection, material), getHitColor(hitPosition.xy), hit);
        #else
            vec3 sampledColor = mix(vec3(0.0), getHitColor(hitPosition.xy), hit);
        #endif

        return sampledColor * ((F * G2) / G1);
    }
#else

//////////////////////////////////////////////////////////
/*------------------ ROUGH REFLECTIONS -----------------*/
//////////////////////////////////////////////////////////

    vec3 computeRoughReflections(vec3 viewPosition, Material material) {
	    vec3 color = vec3(0.0);
        int samples = 0;

        viewPosition += material.normal * 1e-2;

        vec3  viewDirection = normalize(viewPosition);
        mat3  tbn           = constructViewTBN(material.normal);
        float NdotV         = dot(material.normal, -viewDirection);
	
        for(int i = 0; i < ROUGH_REFLECTIONS_SAMPLES; i++, samples++) {
            vec3 microfacet   = tbn * sampleGGXVNDF(-viewDirection * tbn, rand2F(), material.roughness);
		    vec3 rayDirection = reflect(viewDirection, microfacet);	
            float NdotL       = dot(material.normal, rayDirection);

            vec3 hitPosition = vec3(0.0);
                
            float hit  = float(raytrace(depthtex0, viewPosition, rayDirection, ROUGH_REFLECTIONS_STEPS, randF(), hitPosition));
                  hit *= kneemundAttenuation(hitPosition.xy);

            float MdotV   = dot(microfacet, -viewDirection);
            float alphaSq = maxEps(material.roughness * material.roughness);

            vec3  F  = isEyeInWater == 1 ? vec3(fresnelDielectric(MdotV, 1.333, airIOR)) : fresnelDielectricConductor(MdotV, material.N, material.K);
            float G1 = G1SmithGGX(NdotV, alphaSq);
            float G2 = G2SmithGGX(NdotL, NdotV, alphaSq);

             #if defined SKY_FALLBACK
                vec3 sampledColor = mix(getSkyFallback(hitPosition.xy, rayDirection, material), getHitColor(hitPosition.xy), hit);
            #else
                vec3 sampledColor = mix(vec3(0.0), getHitColor(hitPosition.xy), hit);
            #endif

            color += sampledColor * ((F * G2) / G1);
	    }
	    return max0(color / samples);
    }
#endif
