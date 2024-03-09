/***********************************************/
/*          Copyright (C) 2024 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

vec3 sampleHitColor(vec2 hitCoords) {
    #if SSR_REPROJECTION == 1
        return texture(HISTORY_BUFFER, hitCoords).rgb;
    #else
        return texture(ACCUMULATION_BUFFER, hitCoords).rgb;
    #endif
}

vec3 sampleSkyColor(vec2 hitCoords, vec3 reflected, Material material) {
    #if defined WORLD_OVERWORLD || defined WORLD_END
        vec2 coords     = projectSphere(normalize(mat3(gbufferModelViewInverse) * reflected));
        vec3 atmosphere = texture(ATMOSPHERE_BUFFER, saturate(coords)).rgb;

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

float jitter = temporalBlueNoise(gl_FragCoord.xy).r;

#if REFLECTIONS_TYPE == 0
    vec3 computeSmoothReflections(vec3 viewPosition, Material material) {
        float alphaSq = maxEps(material.roughness * material.roughness);

        viewPosition += material.normal * 1e-2;

        vec3  viewDirection = normalize(viewPosition);
        float NdotV         = dot(material.normal, -viewDirection);
        vec3  rayDirection  = viewDirection + 2.0 * NdotV * material.normal; 
        float NdotL         = abs(dot(material.normal, rayDirection));

        vec3 hitPosition;
        float hit = float(raytrace(depthtex0, viewPosition, rayDirection, SMOOTH_REFLECTIONS_STEPS, jitter, RENDER_SCALE, hitPosition));

        vec3 fresnel = vec3(0.0);
        if(isEyeInWater == 1 || material.id == WATER_ID) {
            fresnel = fresnelDielectricDielectric_R(NdotV, vec3(airIOR), vec3(1.333));
        } else {
            fresnel = fresnelDielectricConductor(NdotL, material.N / airIOR, material.K / airIOR);
        }

        float G1 = G1SmithGGX(NdotV, alphaSq);
        float G2 = G2SmithGGX(NdotL, NdotV, alphaSq);

        #if defined SKY_FALLBACK
            vec3 fallback = sampleSkyColor(hitPosition.xy, rayDirection, material);
        #else
            vec3 fallback = vec3(0.0);
        #endif

        return mix(fallback, sampleHitColor(hitPosition.xy), hit) * ((fresnel * G2) / G1);
    }
#else

//////////////////////////////////////////////////////////
/*------------------ ROUGH REFLECTIONS -----------------*/
//////////////////////////////////////////////////////////

    vec3 computeRoughReflections(vec3 viewPosition, Material material) {
        float alphaSq = maxEps(material.roughness * material.roughness);

        viewPosition += material.normal * 1e-2;

        vec3  viewDirection = normalize(viewPosition);
        mat3  tbn           = constructViewTBN(material.normal);
        float NdotV         = dot(material.normal, -viewDirection);

        float G1 = G1SmithGGX(NdotV, alphaSq);

        vec3 tangentViewDirection = -viewDirection * tbn;

        vec3 reflection = vec3(0.0);
        for(int i = 0; i < ROUGH_REFLECTIONS_SAMPLES; i++) {
            vec3  microfacetNormal = tbn * sampleGGXVNDF(tangentViewDirection, rand2F(), material.roughness);
            float MdotV            = dot(microfacetNormal, -viewDirection);
		    vec3  rayDirection     = viewDirection + 2.0 * MdotV * microfacetNormal;	
            float NdotL            = abs(dot(material.normal, rayDirection));

            vec3 hitPosition;
            float hit = float(raytrace(depthtex0, viewPosition, rayDirection, ROUGH_REFLECTIONS_STEPS, jitter, RENDER_SCALE, hitPosition));

            vec3 fresnel = vec3(0.0);
            if(isEyeInWater == 1 || material.id == WATER_ID) {
                fresnel = fresnelDielectricDielectric_R(MdotV, vec3(airIOR), vec3(1.333));
            } else {
                fresnel = fresnelDielectricConductor(MdotV, material.N / airIOR, material.K / airIOR);
            }

            float G2 = G2SmithGGX(NdotL, NdotV, alphaSq);

            #if defined SKY_FALLBACK
                vec3 fallback = sampleSkyColor(hitPosition.xy, rayDirection, material);
            #else
                vec3 fallback = vec3(0.0);
            #endif

            reflection += mix(fallback, sampleHitColor(hitPosition.xy), hit) * ((fresnel * G2) / G1);
	    }
	    return reflection / ROUGH_REFLECTIONS_SAMPLES;
    }
#endif
