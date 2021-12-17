/***********************************************/
/*              Noble RT - 2021              */
/*   Belmu | GNU General Public License V3.0   */
/*   Please do not claim my work as your own.  */
/***********************************************/

#include "/include/post/taa.glsl"
#include "/include/utility/hammersley.glsl"

// Kneemund's Border Attenuation
float Kneemund_Attenuation(vec2 pos, float edgeFactor) {
    pos *= 1.0 - pos;
    return 1.0 - quintic(edgeFactor, 0.0, min(pos.x, pos.y));
}

vec3 getHitColor(vec3 hitPos) {
    #if SSR_REPROJECTION == 1
        hitPos = reprojection(hitPos);
        return texture(colortex3, hitPos.xy).rgb;
    #else
        return texture(colortex0, hitPos.xy).rgb;
    #endif
}

vec3 getSkyFallback(vec2 coords, vec3 reflected) {
    return (texture(colortex7, projectSphere(normalize(mat3(gbufferModelViewInverse) * reflected)) * ATMOSPHERE_RESOLUTION).rgb + celestialBody(reflected, shadowDir)) * getSkyLightmap(coords);
}

/*------------------ SIMPLE REFLECTIONS ------------------*/

#if REFLECTIONS_TYPE == 0
    vec3 simpleReflections(vec2 coords, vec3 viewPos, vec3 normal, float NdotV, vec3 F0, bool isMetal) {
        viewPos += normal * 1e-2;
        vec3 reflected = reflect(normalize(viewPos), normal), hitPos;

        float jitter = TAA == 1 ? uniformAnimatedNoise(hash23(vec3(gl_FragCoord.xy, frameTimeCounter))).x : blueNoise.x;
        float hit    = float(raytrace(viewPos, reflected, SIMPLE_REFLECT_STEPS, jitter, hitPos));

        vec3 fresnel  = specularFresnel(NdotV, F0, isMetal);
        vec3 hitColor = getHitColor(hitPos);

        vec3 color;
        #if SKY_FALLBACK == 1
            color = mix(getSkyFallback(coords, reflected), hitColor, Kneemund_Attenuation(hitPos.xy, ATTENUATION_FACTOR) * hit);
        #else
            color = hitColor * Kneemund_Attenuation(hitPos.xy, ATTENUATION_FACTOR) * hit;
        #endif

        return color * fresnel;
    }
#else

/*------------------ ROUGH REFLECTIONS ------------------*/

    vec3 prefilteredReflections(vec2 coords, vec3 viewPos, vec3 normal, float alpha, vec3 F0, bool isMetal) {
	    vec3 color        = vec3(0.0);
	    float totalWeight = 0.0;

        viewPos     += normal * 1e-2;
        mat3 TBN     = constructViewTBN(normal);
        vec3 viewDir = normalize(viewPos);
        vec3 hitPos;
	
        for(int i = 0; i < ROUGH_SAMPLES; i++) {
            vec2 noise = TAA == 1 ? uniformAnimatedNoise(vec2(randF(rngState), randF(rngState))) : uniformNoise(i, blueNoise);
        
            vec3 microfacet = sampleGGXVNDF(-viewDir * TBN, noise, alpha);
		    vec3 reflected  = reflect(viewDir, TBN * microfacet);	

            float NdotL  = clamp01(dot(normal, reflected));
            vec3 fresnel = specularFresnel(NdotL, F0, isMetal);

            if(NdotL > 0.0) {
                float hit = float(raytrace(viewPos, reflected, ROUGH_REFLECT_STEPS, randF(rngState), hitPos));
                vec3 hitColor;

                float factor = Kneemund_Attenuation(hitPos.xy, ATTENUATION_FACTOR) * hit;

                #if SKY_FALLBACK == 0
                    hitColor = mix(vec3(0.0), getHitColor(hitPos), factor);
                #else
                    hitColor = mix(getSkyFallback(coords, reflected), getHitColor(hitPos), factor);
                #endif

		        color       += NdotL * hitColor * fresnel;
                totalWeight += NdotL;
            }
	    }
	    return color / maxEps(totalWeight);
    }
#endif

/*------------------ REFRACTIONS ------------------*/

#if REFRACTIONS == 1
    vec3 simpleRefractions(vec3 viewPos, vec3 normal, float F0, out vec3 hitPos) {
        viewPos += normal * 1e-2;

        float  ior   = F0toIOR(F0);
        vec3 viewDir = normalize(viewPos);

        vec3 refracted = refract(viewDir, normal, airIOR / ior);
        bool hit       = raytrace(viewPos, refracted, REFRACT_STEPS, randF(rngState), hitPos);
        bool hand      = isHand(texture(depthtex1, hitPos.xy).r);
        if(!hit || hand) hitPos.xy = texCoords;

        float fresnel = fresnelDielectric(maxEps(dot(normal, -viewDir)), ior);
        vec3 hitColor = vec3(
            texture(colortex4, hitPos.xy + vec2(2e-3 * rand(gl_FragCoord.xy))).r,
            texture(colortex4, hitPos.xy).g,
            texture(colortex4, hitPos.xy - vec2(2e-3 * rand(gl_FragCoord.yx))).b
        );

        return hitColor * (1.0 - fresnel);
    }
#endif
