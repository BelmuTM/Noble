/***********************************************/
/*              Noble RT - 2021              */
/*   Belmu | GNU General Public License V3.0   */
/*   Please do not claim my work as your own.  */
/***********************************************/

#include "/include/post/taa.glsl"

// Kneemund's Border Attenuation
float Kneemund_Attenuation(vec2 pos, float edgeFactor) {
    pos *= 1.0 - pos;
    return 1.0 - quintic(edgeFactor, 0.0, minOf2(pos));
}

vec3 getHitColor(vec3 hitPos) {
    #if SSR_REPROJECTION == 1
        hitPos = reprojection(hitPos);
        return texture(colortex8, hitPos.xy).rgb;
    #else
        return texture(colortex0, hitPos.xy).rgb;
    #endif
}

vec3 getSkyFallback(vec3 reflected, Material mat) {
    #if TAA == 1
        float jitter = randF();
    #else
        float jitter = bayer8(gl_FragCoord.xy);
    #endif

    vec3 sky = texture(colortex6, (projectSphere(viewToScene(reflected)) * ATMOSPHERE_RESOLUTION) + (jitter * pixelSize)).rgb;
    return sky * pow2(quintic(0.0, 1.0, mat.lightmap.y));
}

//////////////////////////////////////////////////////////
/*------------------ SIMPLE REFLECTIONS ----------------*/
//////////////////////////////////////////////////////////

#if REFLECTIONS_TYPE == 0
    vec3 simpleReflections(vec3 viewPos, Material mat) {
        viewPos     += mat.normal * 1e-3;
        vec3 viewDir = normalize(viewPos);

        vec3 reflected = reflect(viewDir, mat.normal), hitPos;
        float hit      = float(raytrace(viewPos, reflected, SIMPLE_REFLECT_STEPS, randF(), hitPos));
  
        vec3 fresnel  = BRDFFresnel(maxEps(dot(mat.normal, -viewDir)), mat);
        vec3 hitColor = getHitColor(hitPos);

        vec3 color;
        #if SKY_FALLBACK == 1
            color = mix(getSkyFallback(reflected, mat), hitColor, Kneemund_Attenuation(hitPos.xy, ATTENUATION_FACTOR) * hit);
        #else
            color = hitColor * Kneemund_Attenuation(hitPos.xy, ATTENUATION_FACTOR) * hit;
        #endif

        return color * fresnel;
    }
#else

//////////////////////////////////////////////////////////
/*------------------ ROUGH REFLECTIONS -----------------*/
//////////////////////////////////////////////////////////

    vec3 roughReflections(vec3 viewPos, Material mat) {
	    vec3 color        = vec3(0.0);
	    float totalWeight = EPS;

        viewPos     += mat.normal * 1e-2;
        mat3 TBN     = constructViewTBN(mat.normal);
        vec3 viewDir = normalize(viewPos);
        vec3 hitPos;
	
        for(int i = 0; i < ROUGH_SAMPLES; i++) {
            vec2 noise = TAA == 1 ? vec2(randF(), randF()) : uniformNoise(i, blueNoise);
        
            vec3 microfacet = sampleGGXVNDF(-viewDir * TBN, mix(noise, vec2(0.0), 0.4), mat.rough);
		    vec3 reflected  = reflect(viewDir, TBN * microfacet);	

            float NdotL  = clamp01(dot(mat.normal, reflected));
            vec3 fresnel = BRDFFresnel(NdotL, mat);

            if(NdotL > 0.0) {
                float hit = float(raytrace(viewPos, reflected, ROUGH_REFLECT_STEPS, randF(), hitPos));
                vec3 hitColor;

                float factor = Kneemund_Attenuation(hitPos.xy, ATTENUATION_FACTOR) * hit;

                #if SKY_FALLBACK == 0
                    hitColor = mix(vec3(0.0), getHitColor(hitPos), factor);
                #else
                    hitColor = mix(getSkyFallback(reflected, mat), getHitColor(hitPos), factor);
                #endif

		        color       += NdotL * hitColor * fresnel;
                totalWeight += NdotL;
            }
	    }
	    return color / totalWeight;
    }
#endif

//////////////////////////////////////////////////////////
/*--------------------- REFRACTIONS --------------------*/
//////////////////////////////////////////////////////////

#if REFRACTIONS == 1
    vec3 simpleRefractions(vec3 viewPos, Material mat, inout vec3 hitPos) {
        viewPos += mat.normal * 1e-2;

        float  ior   = F0ToIOR(mat.F0);
        vec3 viewDir = normalize(viewPos);

        vec3 refracted = refract(viewDir, mat.normal, airIOR / ior);
        bool hit       = raytrace(viewPos, refracted, REFRACT_STEPS, randF(), hitPos);
        bool hand      = linearizeDepth(texture(depthtex0, hitPos.xy).r) < 0.56;
        if(!hit || hand) hitPos.xy = texCoords;

        float fresnel = fresnelDielectric(maxEps(dot(mat.normal, -viewDir)), ior);
        vec3 hitColor = vec3(
            texture(colortex0, hitPos.xy + vec2(2e-3 * rand(gl_FragCoord.xy))).r,
            texture(colortex0, hitPos.xy).g,
            texture(colortex0, hitPos.xy - vec2(2e-3 * rand(gl_FragCoord.yx))).b
        );

        return hitColor * (1.0 - fresnel);
    }
#endif
