/***********************************************/
/*              Noble SSRT - 2021              */
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
    if(!raytrace(viewPos, reflected, 28, texture2D(noisetex, texCoords * 5.0).r, hitPos)) return vec3(0.0);

    vec3 L = normalize(shadowLightPosition);
    vec3 H = normalize(viewPos + L);
    vec3 fresnel = Spherical_Gaussian_Fresnel(max(dot(H, L), EPS), F0);

    vec3 hitColor = texture2D(colortex0, hitPos.xy).rgb;
    return hitColor * (fresnel * Kneemund_Attenuation(hitPos.xy, ATTENUATION_FACTOR));
}

/*------------------ ROUGH REFLECTIONS ------------------*/

vec3 prefilteredReflections(vec3 viewPos, vec3 normal, float roughness) {
	vec3 filteredColor = vec3(0.0);
	float totalWeight = 0.0;
	
	//Tangent to View matrix
    vec3 vTangentY = abs(normal.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
    vec3 vTangentX = normalize(cross(vTangentY, normal));
    vTangentY = cross(normal, vTangentX);
    mat3 t2v = mat3(vTangentX, vTangentY, normal);  
	
    for(int i = 0; i < PREFILTER_SAMPLES; i++) {
		vec2 noise = texture2D(noisetex, texCoords * 5.0).xy;
		noise.x = mod(noise.x + GOLDEN_RATIO * i, 1.0);
        noise.y = mod(noise.y + (GOLDEN_RATIO * 2.0) * i, 1.0);
	
        vec3 H = sample_GGX_VNDF(normalize(-viewPos) * t2v, noise.xy, roughness);
		
        vec3 hitPos;
		vec3 reflected = reflect(normalize(viewPos), t2v * H);	
		bool hit = raytrace(viewPos, reflected, 32, noise.x, hitPos);

        float NdotL = max(dot(normal, reflected), EPS);
		if(hit && NdotL >= 0.0) {
			filteredColor += (texture2D(colortex0, hitPos.xy).rgb * NdotL) * Kneemund_Attenuation(hitPos.xy, ATTENUATION_FACTOR);
            totalWeight += NdotL;
		}
	}
	return filteredColor / max(totalWeight, EPS);
}

/*------------------ SIMPLE REFRACTIONS ------------------*/

vec3 simpleRefractions(vec3 color, vec3 viewPos, vec3 normal, float NdotV, float F0) {
    //float ior = F0toIOR(F0);
    viewPos += normal * EPS;
    vec3 refracted = refract(normalize(viewPos), normal, 1.0 / 1.325); // water's ior
    vec3 hitPos;
    if(!raytrace(viewPos, refracted, 28, texture2D(noisetex, texCoords * 5.0).r, hitPos)) return vec3(0.0);

    if(isHand(texture2D(depthtex1, hitPos.xy).r)) return color;

    vec3 fresnel = Fresnel_Schlick(NdotV, vec3(F0));
    vec3 hitColor = texture2D(colortex0, hitPos.xy).rgb;
    return hitColor * (1.0 - fresnel);
}
