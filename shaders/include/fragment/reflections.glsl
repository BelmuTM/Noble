/***********************************************/
/*              Noble RT - 2021              */
/*   Belmu | GNU General Public License V3.0   */
/*   Please do not claim my work as your own.  */
/***********************************************/

#define EDGE_ATTENUATION_FACTOR 0.15

// Kneemund's Edge Attenuation
float KneemundAttenuation(vec2 pos) {
    return 1.0 - quintic(EDGE_ATTENUATION_FACTOR, 0.0, minOf(pos * (1.0 - pos)));
}

vec3 getHitColor(in vec3 hitPos) {
    #if SSR_REPROJECTION == 1
        hitPos -= getVelocity(hitPos);
        return texture(colortex8, hitPos.xy).rgb;
    #else
        return texture(colortex4, hitPos.xy).rgb;
    #endif
}

vec3 getSkyFallback(vec3 reflected, Material mat) {
    #ifdef WORLD_OVERWORLD
        vec2 coords = projectSphere(mat3(gbufferModelViewInverse) * reflected);
        vec3 sky    = texture(colortex12, clamp01(coords + randF() * pixelSize)).rgb;

        return sky * getSkyLightFalloff(mat.lightmap.y);
    #else
        return vec3(0.0);
    #endif
}

//////////////////////////////////////////////////////////
/*------------------ SIMPLE REFLECTIONS ----------------*/
//////////////////////////////////////////////////////////

#if REFLECTIONS_TYPE == 0
    vec3 simpleReflections(vec3 viewPos, Material mat) {
        viewPos     += mat.normal * 1e-2;
        vec3 viewDir = normalize(viewPos);

        vec3 rayDir   = reflect(viewDir, mat.normal); vec3 hitPos;
        float hit     = float(raytrace(depthtex0, viewPos, rayDir, SIMPLE_REFLECT_STEPS, randF(), hitPos));
              hit    *= KneemundAttenuation(hitPos.xy);
        vec3 hitColor = getHitColor(hitPos);

        #ifdef SKY_FALLBACK
            vec3 color = mix(getSkyFallback(rayDir, mat), hitColor, hit);
        #else
            vec3 color = mix(vec3(0.0), hitColor, hit);
        #endif

        float NdotL = abs(dot(mat.normal, rayDir));
        float NdotV = dot(mat.normal, -viewDir);

        vec3  F  = fresnelComplex(NdotL, mat);
        float G1 = G1SmithGGX(NdotV, mat.rough);
        float G2 = G2SmithGGX(NdotL, NdotV, mat.rough);

        return NdotV > 0.0 && NdotL > 0.0 ? color * F : vec3(0.0);
    }
#else

//////////////////////////////////////////////////////////
/*------------------ ROUGH REFLECTIONS -----------------*/
//////////////////////////////////////////////////////////

    vec3 roughReflections(vec3 viewPos, Material mat) {
	    vec3 color = vec3(0.0); vec3 hitPos;
        int samples = 0;

        viewPos     += mat.normal * 1e-2;
        mat3 TBN     = constructViewTBN(mat.normal);
        vec3 viewDir = normalize(viewPos);
        float NdotV  = dot(mat.normal, -viewDir);
	
        for(int i = 0; i < ROUGH_SAMPLES; i++) {
            vec2 noise      = vec2(randF(), randF());
            vec3 microfacet = TBN * sampleGGXVNDF(-viewDir * TBN, noise, mat.rough);
		    vec3 rayDir     = reflect(viewDir, microfacet);	
            float NdotL     = abs(dot(mat.normal, rayDir));

            if(NdotV > 0.0 && NdotL > 0.0) {
                float hit     = float(raytrace(depthtex0, viewPos, rayDir, ROUGH_REFLECT_STEPS, randF(), hitPos));
                      hit    *= KneemundAttenuation(hitPos.xy);
                vec3 hitColor = getHitColor(hitPos);

                #ifdef SKY_FALLBACK
                    hitColor = mix(getSkyFallback(rayDir, mat), getHitColor(hitPos), hit);
                #else
                    hitColor = mix(vec3(0.0), getHitColor(hitPos), hit);
                #endif

                float MdotV = dot(microfacet, -viewDir);

                vec3  F  = isEyeInWater == 1 ? vec3(fresnelDielectric(MdotV, 1.329, airIOR)) : fresnelComplex(MdotV, mat);
                float G1 = G1SmithGGX(NdotV, mat.rough);
                float G2 = G2SmithGGX(NdotL, NdotV, mat.rough);

                color += hitColor * ((F * G2) / G1);
                samples++;
            }
	    }
	    return max0(color * rcp(samples));
    }
#endif

//////////////////////////////////////////////////////////
/*--------------------- REFRACTIONS --------------------*/
//////////////////////////////////////////////////////////

#if REFRACTIONS == 1
    vec3 refractions(vec3 viewPos, vec3 scenePos, Material mat, inout vec3 hitPos) {
        float ior    = f0ToIOR(mat.F0);
        vec3 viewDir = normalize(viewPos);

        vec3 refracted = refract(viewDir, mat.normal, airIOR / ior);
        bool hit       = raytrace(depthtex1, viewPos, refracted, REFRACT_STEPS, randF(), hitPos);
        if(!hit || isHand(hitPos.xy)) { hitPos.xy = texCoords; }

        float n1 = airIOR, n2 = ior;
        if(isEyeInWater == 1) { n1 = 1.329; n2 = airIOR; }

        float fresnel = fresnelDielectric(maxEps(dot(mat.normal, -viewDir)), n1, n2);
        vec3 hitColor = texture(colortex13, hitPos.xy).rgb;

        float distThroughMedium = clamp(distance(viewToScene(screenToView(hitPos)), scenePos), EPS, 5.0);
        vec3  beer              = mat.blockId == 1 ? vec3(1.0) : exp(-(1.0 - mat.albedo) * distThroughMedium);

        return max0(hitColor * (1.0 - fresnel) * beer);
    }
#endif
