/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

#define ATTENUATION_FACTOR 0.6

// LVutner's border attenuation
float LVutner_Attenuation(vec2 pos, float edgeFactor) {
    float borderDist = min(1.0 - max(pos.x, pos.y), min(pos.x, pos.y));
    float border = clamp(borderDist > edgeFactor ? 1.0 : borderDist / edgeFactor, 0.0, 1.0);
    return border;
}

// Belmu's border attenuation
float Belmu_Attenuation(vec2 pos, float edgeFactor) {
    vec2 att = 1.0 - smoothstep(vec2(edgeFactor), vec2(1.0), abs(pos));
    return att.x * att.y;
}

// Kneemund's border attenuation
float Kneemund_Attenuation(vec2 pos, float edgeFactor) {
    pos *= 1.0 - pos;
    return 1.0 - smoothstep(edgeFactor, 0.0, min(pos.x, pos.y));
}

/////////////// SIMPLE REFLECTIONS ///////////////

vec3 simpleReflections(vec3 color, vec3 viewPos, vec3 normal, float NdotV, float F0) {
    viewPos += normal * 0.01;
    vec3 reflected = reflect(normalize(viewPos), normal);
    vec2 hitPos = vec2(0.0);
    bool intersect = raytrace(viewPos, reflected, 36, fract((texCoords.x + texCoords.y) * 0.5), hitPos);

    if(!intersect) return color;
    if(isHand(texture2D(depthtex0, hitPos).r)) return color;

    float fresnel = F0 + (1.0 - F0) * pow(1.0 - NdotV, 5.0);
    vec3 hitColor = texture2D(colortex0, hitPos).rgb;
    return mix(color, hitColor, fresnel * Kneemund_Attenuation(hitPos, ATTENUATION_FACTOR));
}

/////////////// ROUGH REFLECTIONS ///////////////

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
#define BRDF_BIAS 0.26
#define PREFILTER_SAMPLES 10

vec3 prefilteredReflections(vec3 viewPos, vec3 normal, float roughness) {
	vec3 filteredColor = vec3(0.0);
	float totalWeight = 0.0;
	
	//Tangent to View matrix
    vec3 vTangentY = abs(normal.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
    vec3 vTangentX = normalize(cross(vTangentY, normal));
    vTangentY = cross(normal, vTangentX);
    mat3 t2v = mat3(vTangentX, vTangentY, normal);  
	
    for(int i = 0; i < PREFILTER_SAMPLES; i++) {
		vec3 noise = hash33(vec3(gl_FragCoord.xy, i));
		noise.y = mix(noise.y, 0.0, BRDF_BIAS);
	
		vec3 H = Importance_Sample_GGX(noise.xy, roughness);
		H = t2v * H;
		
		vec3 reflected = reflect(normalize(viewPos), H);	
		vec2 hitPos;
		bool intersect = raytrace(viewPos, reflected, 16, noise.z, hitPos);

		if(intersect) {
			float NdotL = max(dot(normal, reflected), 0.0);
			//hitPos = reprojection(vec3(hitPos, texture2D(depthtex0, hitPos).x));
			
			if(NdotL >= 0.0) {
				filteredColor += (texture2D(colortex0, hitPos.xy).rgb * NdotL) * Kneemund_Attenuation(hitPos, ATTENUATION_FACTOR);
				totalWeight += NdotL;
			}
		}
	}
	return clamp(filteredColor / totalWeight, 0.0, 1.0);
}

/////////////// REFRACTION ///////////////

vec3 simpleRefraction(vec3 color, vec3 viewPos, vec3 normal, float NdotV, float F0) {
    float eta = 1.0 / 1.333; // Water

    viewPos += normal * 0.01;
    vec3 refracted = refract(normalize(viewPos), normal, eta);
    vec2 hitPos = vec2(0.0);
    bool intersect = raytraceRefraction(viewPos, refracted, 8, fract((texCoords.x + texCoords.y) * 0.5), hitPos);

    if(!intersect) return color;
    if(isHand(texture2D(depthtex0, hitPos).r)) return color;

    float fresnel = F0 + (1.0 - F0) * pow(1.0 - NdotV, 5.0);
    vec3 hitColor = texture2D(colortex0, hitPos).rgb;
    return hitColor;
}
