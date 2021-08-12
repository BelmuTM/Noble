/***********************************************/
/*              Noble RT - 2021              */
/*   Belmu | GNU General Public License V3.0   */
/*   Please do not claim my work as your own.  */
/***********************************************/

// LVutner's Border Attenuation
float LVutner_Attenuation(vec2 pos, float edgeFactor) {
    float borderDist = min(1.0 - max(pos.x, pos.y), min(pos.x, pos.y));
    float border = clamp(borderDist > edgeFactor ? 1.0 : borderDist / edgeFactor, 0.0, 1.0);
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

/*------------------ SIMPLE REFLECTIONS ------------------*/

vec3 simpleReflections(vec3 viewPos, vec3 normal, float NdotV, vec3 F0) {
    viewPos += normal * EPS;
    vec3 reflected = reflect(normalize(viewPos), normal);
    vec3 hitPos;

    float jitter;
    #if TAA == 1
        jitter = uniformAnimatedNoise().r;
    #else
        jitter = blueNoise().r;
    #endif

    if(!raytrace(viewPos, reflected, SIMPLE_REFLECT_STEPS, jitter, hitPos)) return vec3(0.0);

    vec3 L = normalize(shadowLightPosition);
    vec3 H = normalize(viewPos + L);
    vec3 fresnel = sphericalGaussianFresnel(max(dot(H, L), EPS), F0);

    vec3 hitColor = texture2D(colortex0, hitPos.xy).rgb;
    return hitColor * (fresnel * Kneemund_Attenuation(hitPos.xy, ATTENUATION_FACTOR));
}

/*------------------ ROUGH REFLECTIONS ------------------*/

vec3 prefilteredReflections(vec3 viewPos, vec3 normal, float roughness) {
	vec3 filteredColor = vec3(0.0);
	float weight = 0.0;
	
    vec3 tangent = normalize(cross(gbufferModelView[1].xyz, normal));
    mat3 TBN = mat3(tangent, cross(normal, tangent), normal);
    vec3 hitPos; vec2 noise;

    #if TAA == 1
        noise = uniformAnimatedNoise();
    #endif
	
    for(int i = 0; i < PREFILTER_SAMPLES; i++) {
        #if TAA == 0
            noise = uniformNoise(i);
        #endif
        vec3 H = sampleGGXVNDF(normalize(-viewPos) * TBN, noise.rg, roughness);
		
		vec3 reflected = reflect(normalize(viewPos), TBN * H);	
		bool hit = raytrace(viewPos, reflected, ROUGH_REFLECT_STEPS, blueNoise().b, hitPos);

        float NdotL = max(dot(normal, reflected), EPS);
		if(hit && NdotL > 0.0) {
			filteredColor += (texture2D(colortex0, hitPos.xy).rgb * NdotL) * Kneemund_Attenuation(hitPos.xy, ATTENUATION_FACTOR);
            weight += NdotL;
		}
	}
	return filteredColor / max(EPS, weight);
}

/*------------------ SIMPLE REFRACTIONS ------------------*/

vec3 simpleRefractions(vec3 viewPos, vec3 normal, float NdotV, float F0, out vec3 hitPos) {
    //float ior = F0toIOR(F0);
    viewPos += normal * EPS;
    vec3 refracted = refract(normalize(viewPos), normal, 1.0 / 1.325); // water's ior

    if(!raytrace(viewPos, refracted, REFRACT_STEPS, blueNoise().r, hitPos)) return vec3(0.0);
    if(isHand(texture2D(depthtex1, hitPos.xy).r)) return vec3(0.0);

    vec3 fresnel = fresnelSchlick(NdotV, vec3(F0));
    vec3 hitColor = texture2D(colortex4, hitPos.xy).rgb;
    return hitColor * (1.0 - fresnel) * Kneemund_Attenuation(hitPos.xy, 0.15);
}
