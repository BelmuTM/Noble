/*
  Author: Belmu (https://github.com/BelmuTM/)
  */

#define SSGI_SCALE 0.5
#define SSGI_SAMPLES 12 // [2 4 6 12 24 32 48 64]
#define SSGI_BIAS 0.007f

vec3 computeSSGI(vec3 viewPos, vec3 normal) {
    vec3 illumination = vec3(0.0f);
    vec3 prevPos = vec3(0.0f);

    // Avoids affecting hand
		if(isHand(texture2D(depthtex0, TexCoords).r)) return illumination;

    float PDF = 1.0f / (2.0f * PI);
    vec3 sampleOrigin = viewPos + normal * 0.01f;

    for(int i = 0; i < SSGI_SAMPLES; i++) {
        vec3 noise = hash33(vec3(TexCoords, i));
        //noise = fract(noise + vec3(frameTimeCounter) * 17.0f);

        //Sampling pos
        vec3 sampleDir = cosWeightedRandomHemisphereDirection(normal, noise.xy);
        float NdotD = dot(normal, sampleDir);
        sampleDir *= SSGI_BIAS;

        // Ray trace
        if(!RayTraceSSGI(sampleOrigin, sampleDir, prevPos)) continue;

        vec3 sampleColor = texture2D(colortex0, prevPos.xy).rgb;
        // Temporal Accumulation
        vec2 offset = hash22(prevPos.xy + sin(frameTimeCounter));
        sampleColor += texture2D(colortex0, prevPos.xy + (offset * 2.0f - 1.0f) * 0.005f).rgb;

        illumination += sampleColor * NdotD * noise.x / PDF;
    }
    illumination /= SSGI_SAMPLES;
    illumination *= SSGI_SCALE;

    return illumination;
}
