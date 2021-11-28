/***********************************************/
/*              Noble RT - 2021              */
/*   Belmu | GNU General Public License V3.0   */
/*   Please do not claim my work as your own.  */
/***********************************************/

#include "/include/post/taa.glsl"

// Kneemund's Border Attenuation
float Kneemund_Attenuation(vec2 pos, float edgeFactor) {
    pos *= 1.0 - pos;
    return 1.0 - smoothstep(edgeFactor, 0.0, min(pos.x, pos.y));
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

vec3 simpleReflections(vec2 coords, vec3 viewPos, vec3 normal, float NdotV, vec3 F0, bool isMetal) {
    viewPos += normal * 1e-2;
    vec3 reflected = reflect(normalize(viewPos), normal), hitPos;

    float jitter = TAA == 1 ? uniformAnimatedNoise(hash23(vec3(gl_FragCoord.xy, frameTimeCounter))).x : blueNoise.x;
    float hit = float(raytrace(viewPos, reflected, SIMPLE_REFLECT_STEPS, jitter, hitPos));

    vec3 fresnel = specularFresnel(NdotV, F0.r, F0, isMetal);
    vec3 hitColor = getHitColor(hitPos);

    vec3 color;
    #if SKY_FALLBACK == 1
        color = mix(getSkyFallback(coords, reflected), hitColor, Kneemund_Attenuation(hitPos.xy, 0.2) * hit);
    #else
        color = hitColor * Kneemund_Attenuation(hitPos.xy, ATTENUATION_FACTOR) * hit;
    #endif
    return color * fresnel;
}

/*------------------ ROUGH REFLECTIONS ------------------*/

vec3 prefilteredReflections(vec2 coords, vec3 viewPos, vec3 normal, float alpha, vec3 F0, bool isMetal) {
	vec3 filteredColor = vec3(0.0);
	float totalWeight  = 0.0;

    mat3 TBN = constructViewTBN(normal);
    vec3 viewDir = normalize(viewPos);
    vec3 hitPos; vec2 noise;

    viewPos += normal * 1e-2;
	
    for(int i = 0; i < PREFILTER_SAMPLES; i++) {
        vec2 noise = TAA == 1 ? uniformAnimatedNoise(hash22(gl_FragCoord.xy + frameTimeCounter * 10.0)) : uniformNoise(i, blueNoise);
        
        vec3 microfacet = sampleGGXVNDF(-viewDir * TBN, noise, alpha);
		vec3 reflected  = reflect(viewDir, TBN * microfacet);	
		float hit = float(raytrace(viewPos, reflected, ROUGH_REFLECT_STEPS, noise.y, hitPos));

        float NdotL   = maxEps(dot(microfacet, reflected));
        vec3 hitColor = getHitColor(hitPos);
        vec3 fresnel  = specularFresnel(NdotL, F0.r, F0, isMetal);

        #if SKY_FALLBACK == 1
			filteredColor += (mix(getSkyFallback(coords, reflected), hitColor, Kneemund_Attenuation(hitPos.xy, 0.15) * hit) * NdotL) * fresnel;
        #else
            filteredColor += ((hitColor * NdotL) * (Kneemund_Attenuation(hitPos.xy, ATTENUATION_FACTOR) * hit)) * fresnel;
        #endif
        totalWeight += NdotL;
	}
	return filteredColor / maxEps(totalWeight);
}

/*------------------ SIMPLE REFRACTIONS ------------------*/

vec3 simpleRefractions(vec3 viewPos, vec3 normal, float F0, out vec3 hitPos) {
    viewPos += normal * 1e-2;
    float ior = F0toIOR(F0);

    vec3 refracted = refract(normalize(viewPos), normal, airIOR / ior);
    bool hit       = raytrace(viewPos, refracted, REFRACT_STEPS, taaNoise, hitPos);
    bool hand      = isHand(texture(depthtex1, hitPos.xy).r);
    if(!hit || hand) hitPos.xy = texCoords;

    float fresnel = fresnelDielectric(maxEps(dot(normal, -normalize(viewPos))), ior);
    vec3 hitColor = texture(colortex4, hitPos.xy).rgb;
    return hitColor * (1.0 - fresnel);
}
