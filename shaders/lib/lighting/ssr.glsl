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
        return texture2D(colortex3, hitPos.xy).rgb;
    #else
        return texture2D(colortex0, hitPos.xy).rgb;
    #endif
}

/*------------------ SIMPLE REFLECTIONS ------------------*/

vec3 simpleReflections(vec2 coords, vec3 viewPos, vec3 normal, float NdotV, vec3 F0, bool isMetal) {
    vec3 reflected = reflect(normalize(viewPos), normal);
    vec3 hitPos;

    float jitter = TAA == 1 ? uniformAnimatedNoise(blueNoise().rg).r : blueNoise().r;
    float hit = float(raytrace(viewPos, reflected, SIMPLE_REFLECT_STEPS, jitter, hitPos));

    vec3 L = shadowLightPosition * 0.01;
    vec3 H = normalize(viewPos + L);
    vec3 fresnel = schlickGaussian(saturate(dot(H, L)), F0);
    vec3 hitColor = getHitColor(hitPos);

    vec3 color = vec3(0.0);
    #if SKY_FALLBACK == 1
        vec3 sky = getDayTimeSkyGradient(mat3(gbufferModelViewInverse) * reflected, viewPos) * getSkyLightmap(coords);
        color = mix(sky * float(isMetal), hitColor, Kneemund_Attenuation(hitPos.xy, 0.2) * hit);
    #else
        color = hitColor * Kneemund_Attenuation(hitPos.xy, ATTENUATION_FACTOR);
    #endif
    return color * fresnel;
}

/*------------------ ROUGH REFLECTIONS ------------------*/

vec3 prefilteredReflections(vec2 coords, vec3 viewPos, vec3 normal, float roughness, bool isMetal) {
	vec3 filteredColor = vec3(0.0);
	float weight = 0.0;

    vec3 viewDir = normalize(viewPos);
    vec3 hitPos; vec2 noise;
	
    vec3 tangent = normalize(cross(gbufferModelView[1].xyz, normal));
    mat3 TBN = mat3(tangent, cross(normal, tangent), normal);
	
    for(int i = 0; i < PREFILTER_SAMPLES; i++) {
        vec2 noise = TAA == 1 ? uniformAnimatedNoise(hash22(gl_FragCoord.xy)) : uniformNoise(i);
        
        vec3 microfacet = sampleGGXVNDF(-viewDir * TBN, noise.rg, roughness);
		vec3 reflected = reflect(viewDir, TBN * microfacet);	
		float hit = float(raytrace(viewPos, reflected, ROUGH_REFLECT_STEPS, noise.r, hitPos));

        float NdotL = max(0.0, dot(normal, reflected));
		if(NdotL > 0.0) {
            vec3 hitColor = getHitColor(hitPos);

            #if SKY_FALLBACK == 1
                vec3 sky = getDayTimeSkyGradient(mat3(gbufferModelViewInverse) * reflected, viewPos) * getSkyLightmap(coords);
			    filteredColor += mix(sky * float(isMetal), hitColor, Kneemund_Attenuation(hitPos.xy, 0.1) * hit) * NdotL;
            #else
                filteredColor += (hitColor * NdotL) * (Kneemund_Attenuation(hitPos.xy, ATTENUATION_FACTOR) * hit);
            #endif
            weight += NdotL;
		}
	}
	return saturate(filteredColor / max(EPS, weight));
}

/*------------------ SIMPLE REFRACTIONS ------------------*/

vec3 simpleRefractions(vec3 background, vec3 viewPos, vec3 normal, float NdotV, float F0, out vec3 hitPos) {
    float ior = F0toIOR(F0); // 1.329 = water's IOR
    viewPos += normal * EPS;

    vec3 refracted = refract(normalize(viewPos), normal, 1.0 / ior); // water's ior
    float jitter = TAA == 1 ? uniformAnimatedNoise(blueNoise().rg).r : blueNoise().r;

    float hit = float(raytrace(viewPos, refracted, REFRACT_STEPS, jitter, hitPos));
    if(isHand(texture2D(depthtex1, hitPos.xy).r)) return vec3(0.0);

    vec3 fresnel = fresnelSchlick(NdotV, vec3(F0));
    vec3 hitColor = texture2D(colortex4, hitPos.xy).rgb;
    return mix(background, hitColor, Kneemund_Attenuation(hitPos.xy, 0.07) * hit) * (1.0 - fresnel);
}
