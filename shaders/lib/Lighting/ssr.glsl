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

vec3 simpleReflections(vec3 color, vec3 viewPos, vec3 normal, float NdotV, vec3 F0) {
    viewPos += normal * 0.01;
    vec3 reflected = reflect(normalize(viewPos), normal);
    vec3 hitPos;
    bool hit = raytrace(viewPos, reflected, 28, bayer64(gl_FragCoord.xy), hitPos);

    if(!hit) return color;

    vec3 fresnel = F0 + (1.0 - F0) * pow(1.0 - NdotV, 5.0) + rainStrength;
    vec3 hitColor = texture2D(colortex0, hitPos.xy).rgb;
    return mix(color, hitColor, fresnel * Kneemund_Attenuation(hitPos.xy, ATTENUATION_FACTOR));
}

/*------------------ ROUGH REFLECTIONS ------------------*/

vec3 Importance_Sample_GGX(vec2 Xi, float roughness) {	
	// Importance sampling - UE4
    float phi = 2.0 * PI * Xi.x;
    float a = roughness * roughness;

    float cosTheta = sqrt((1.0 - Xi.y) / (1.0 + (a*a - 1.0) * Xi.y));
    float sinTheta = sqrt(1.0 - cosTheta*cosTheta);

    // Spherical to Cartesian coordinates
    vec3 H;
    H.x = cos(phi) * sinTheta;
    H.y = sin(phi) * sinTheta;
    H.z = cosTheta;
    return H;
}

/*
    Thanks LVutner.#7259 a lot for the help!
    Inspired of UE4, provided by LVutner and modified by Belmu.
*/
vec3 prefilteredReflections(vec3 viewPos, vec3 normal, float roughness) {
	vec3 filteredColor = vec3(0.0);
	float totalWeight = 0.0;
	
	//Tangent to View matrix
    vec3 vTangentY = abs(normal.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
    vec3 vTangentX = normalize(cross(vTangentY, normal));
    vTangentY = cross(normal, vTangentX);
    mat3 t2v = mat3(vTangentX, vTangentY, normal);  
	
    for(int i = 0; i < PREFILTER_SAMPLES; i++) {
		vec2 noise = hash22(gl_FragCoord.xy + i);
		noise.y = mix(noise.y, 1.0, BRDF_BIAS);
	
		vec3 H = Importance_Sample_GGX(noise.xy, roughness);
		
        vec3 hitPos;
		vec3 reflected = reflect(normalize(viewPos), t2v * H);	
		bool hit = raytrace(viewPos, reflected, 20, noise.x, hitPos);

        float NdotL = max(dot(normal, reflected), 0.0);
		if(hit && NdotL >= 0.0) {
			filteredColor += (texture2D(colortex0, hitPos.xy).rgb * NdotL) * Kneemund_Attenuation(hitPos.xy, ATTENUATION_FACTOR);
			totalWeight += NdotL;
		}
	}
	return filteredColor / max(totalWeight, EPS);
}

/*------------------ SIMPLE REFRACTIONS ------------------*/

vec3 simpleRefractions(vec3 color, vec3 viewPos, vec3 normal, float NdotV, vec3 F0) {
    vec3 refracted = refract(normalize(viewPos), normal, 1.0 / 1.333);
    vec3 hitPos;
    bool hit = raytrace(viewPos, refracted, 28, bayer64(gl_FragCoord.xy), hitPos);

    vec3 fresnel = F0 + (1.0 - F0) * pow(1.0 - NdotV, 5.0) + rainStrength;
    vec3 hitColor = texture2D(colortex0, hitPos.xy).rgb;
    return hitColor;
}
