/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

#define SSGI_SCALE 2
#define SSGI_SAMPLES 12 // [2 4 6 12 24 32 48 64]

vec3 computeSSGI(vec3 viewPos, vec3 normal) {
    vec2 texCoords = TexCoords;
    vec3 illumination = vec3(0.0f);
    vec2 prevPos = vec2(0.0f);

    // Avoids affecting hand
	if(isHand(texture2D(depthtex0, texCoords).r)) return illumination;

    float PDF = 1.0f / (2.0f * PI);
    vec3 sampleOrigin = viewPos + normal * 0.01f;

    for(int i = 0; i < SSGI_SAMPLES; i++) {
        vec3 noise = hash33(vec3(texCoords, i));
        noise = fract(noise + vec3(frameTime) * 17.0f);

        //Sampling pos
        vec3 sampleDir = cosWeightedRandomHemisphereDirection(normal, noise.xy);
        float NdotD = dot(normal, sampleDir);

        // Ray trace
        if(!raytrace(sampleOrigin, sampleDir, bayer64(texCoords), prevPos)) continue;

        vec3 sampleColor = texture2D(colortex0, prevPos).rgb;
        illumination += sampleColor * NdotD * noise.x / PDF;
    }
    illumination /= SSGI_SAMPLES;
    illumination *= SSGI_SCALE;

    return illumination;
}
