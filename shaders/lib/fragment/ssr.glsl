/***********************************************/
/*              Noble RT - 2021              */
/*   Belmu | GNU General Public License V3.0   */
/*   Please do not claim my work as your own.  */
/***********************************************/

#include "/lib/post/taa.glsl"

// LVutner's Border Attenuation
float LVutner_Attenuation(vec2 pos, float edgeFactor) {
    float borderDist = min(1.0 - max(pos.x, pos.y), min(pos.x, pos.y));
    float border = saturate(borderDist > edgeFactor ? 1.0 : borderDist / edgeFactor);
    return border;
}

// Belmu's Border Attenuation
float Belmu_Attenuation(vec2 pos, float edgeFactor) {
    vec2 att = 1.0 - smoothstep(vec2(edgeFactor), vec2(1.0), abs(pos));
    return att.x * att.y;
}

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

/*------------------ SIMPLE REFLECTIONS ------------------*/

vec3 simpleReflections(vec2 coords, vec3 viewPos, vec3 normal, float NdotV, vec3 F0, bool isMetal) {
    vec3 reflected = reflect(normalize(viewPos), normal), hitPos;

    float jitter = TAA == 1 ? uniformAnimatedNoise(hash22(gl_FragCoord.xy + frameTimeCounter)).x : blueNoise.x;
    float hit = float(raytrace(viewPos, reflected, SIMPLE_REFLECT_STEPS, jitter, hitPos));

    vec3 fresnel = cookTorranceFresnel(NdotV, F0.r, F0, isMetal);
    vec3 hitColor = getHitColor(hitPos);

    vec3 color = vec3(0.0);
    #if SKY_FALLBACK == 1
        vec3 sky = getDayTimeSkyGradient(mat3(gbufferModelViewInverse) * reflected, viewPos) * getSkyLightmap(coords);
        color = mix(sky, hitColor, Kneemund_Attenuation(hitPos.xy, 0.2) * hit);
    #else
        color = hitColor * Kneemund_Attenuation(hitPos.xy, ATTENUATION_FACTOR) * hit;
    #endif
    return color * fresnel;
}

/*------------------ ROUGH REFLECTIONS ------------------*/

vec3 prefilteredReflections(vec2 coords, vec3 viewPos, vec3 normal, float alpha, vec3 F0, bool isMetal) {
	vec3 filteredColor = vec3(0.0);
	float weight = 0.0;

    vec3 viewDir = normalize(viewPos);
    vec3 hitPos; vec2 noise;
	
    vec3 tangent = normalize(cross(gbufferModelView[1].xyz, normal));
    mat3 TBN = mat3(tangent, cross(normal, tangent), normal);
	
    for(int i = 0; i < PREFILTER_SAMPLES; i++) {
        vec2 noise = TAA == 1 ? uniformAnimatedNoise(hash22(gl_FragCoord.xy + frameTimeCounter)) : uniformNoise(i, blueNoise);
        
        vec3 microfacet = sampleGGXVNDF(-viewDir * TBN, noise, alpha);
		vec3 reflected = reflect(viewDir, TBN * microfacet);	
		float hit = float(raytrace(viewPos, reflected, ROUGH_REFLECT_STEPS, -noise.y, hitPos));

        float NdotL = max(EPS, dot(microfacet, reflected));
        vec3 hitColor = getHitColor(hitPos);
        vec3 fresnel = cookTorranceFresnel(NdotL, F0.r, F0, isMetal);

        #if SKY_FALLBACK == 1
            vec3 sky = getDayTimeSkyGradient(mat3(gbufferModelViewInverse) * reflected, viewPos) * getSkyLightmap(coords);
			filteredColor += (mix(sky, hitColor, Kneemund_Attenuation(hitPos.xy, 0.15) * hit) * NdotL) * fresnel;
        #else
            filteredColor += ((hitColor * NdotL) * (Kneemund_Attenuation(hitPos.xy, ATTENUATION_FACTOR) * hit)) * fresnel;
        #endif
        weight += NdotL;
	}
	return filteredColor / max(EPS, weight);
}

/*------------------ SIMPLE REFRACTIONS ------------------*/

vec3 simpleRefractions(vec3 background, vec3 viewPos, vec3 normal, float NdotV, float F0, out vec3 hitPos) {
    viewPos += normal * EPS;

    vec3 refracted = refract(normalize(viewPos), normal, airIOR / F0toIOR(F0));
    float hit  = float(raytrace(viewPos, refracted, REFRACT_STEPS, taaNoise, hitPos));
    float hand = float(!isHand(texture(depthtex1, hitPos.xy).r));

    vec3 fresnel = fresnelSchlick(NdotV, vec3(F0));
    vec3 hitColor = texture(colortex4, hitPos.xy).rgb;

    return mix(background, hitColor, Kneemund_Attenuation(hitPos.xy, 0.07) * hit * hand) * (1.0 - fresnel);
}
