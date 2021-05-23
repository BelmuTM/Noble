/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

#define SSGI_SCALE 2
#define SSGI_SAMPLES 12 // [2 4 6 12 24 32 48 64]

vec3 computeSSGI(vec3 viewPos, vec3 normal) {
    vec3 illumination = vec3(0.0);
    vec2 prevPos = vec2(0.0);

    // Avoids affecting hand
	if(isHand(texture2D(depthtex0, TexCoords).r)) return illumination;

    float PDF = 1.0 / (2.0 * PI);
    vec3 sampleOrigin = viewPos + normal * 0.01;

    for(int i = 0; i < SSGI_SAMPLES; i++) {
        vec3 noise = hash33(vec3(TexCoords, i));
        #if SSGI_TEMPORAL_ACCUMULATION == 1
            noise = fract(noise + vec3(frameTime * 17.0));
        #endif

        //Sampling pos
        vec3 sampleDir = cosWeightedRandomHemisphereDirection(normal, noise.xy);
        float NdotD = dot(normal, sampleDir);

        // Ray trace
        if(!raytrace(sampleOrigin, sampleDir, bayer64(TexCoords), prevPos)) continue;
        // Avoids affecting hand
	    if(isHand(texture2D(depthtex0, prevPos).r)) return illumination;

        vec3 sampleColor = texture2D(colortex0, prevPos).rgb;
        illumination += sampleColor * NdotD * noise.x / PDF;
    }
    illumination /= SSGI_SAMPLES;
    illumination *= SSGI_SCALE;

    return illumination;
}
