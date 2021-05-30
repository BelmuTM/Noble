/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

#define SSGI_SCALE 2
#define SSGI_SAMPLES 24 // [2 4 6 12 24 32 48 64 80]

vec3 computeSSGI(vec3 viewPos, vec3 normal) {
    vec3 illumination = vec3(0.0);
    vec2 prevPos = vec2(0.0);

    // Avoids affecting hand
	if(isHand(texture2D(depthtex0, texCoords).r)) return illumination;

    float PDF = 1.0 / (2.0 * PI);
    vec3 sampleOrigin = viewPos + normal * 0.01;

    for(int i = 0; i < SSGI_SAMPLES; i++) {
        vec3 noise = hash33(vec3(texCoords, i));
        noise = fract(noise + vec3(frameTime * 17.0));

        /*
        vec3 tangent = normalize(noise - normal * dot(noise, normal));
        vec3 bitangent = cross(normal, tangent);
        mat3 TBN = mat3(tangent, bitangent, normal);
        vec3 sampleDir = TBN * hemisphereSample(noise.x, noise.y);
        */

        // vec3 sampleDir = cosWeightedRandomHemisphereDirection(normal, noise.xy);

        //Sampling pos
        vec3 sampleDir = cosWeightedRandomHemisphereDirection(normal, noise.xy);
        float NdotD = max(dot(normal, sampleDir), 0.001);

        // Ray trace
        if(!raytrace(sampleOrigin, sampleDir, 24, prevPos)) continue;
        // Avoids affecting hand
	    if(isHand(texture2D(depthtex0, prevPos).r)) return vec3(0.0);

        vec3 sampleColor = texture2D(colortex0, prevPos).rgb;
        illumination += sampleColor * NdotD * noise.x / PDF;
    }
    illumination /= SSGI_SAMPLES;
    illumination *= SSGI_SCALE;

    return illumination;
}
