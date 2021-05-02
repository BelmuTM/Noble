/*
  Author: Belmu (https://github.com/BelmuTM/)
  */

#define SSGI_SCALE 6
#define SSGI_SAMPLES 12 // [2 4 6 12 24 32 64]
#define SSGI_BIAS 0.01f // 1.0f -> 0.01 (Smaller = More lag | Bigger = Less lag)

vec4 computeSSGI(vec3 viewPos, vec3 normal) {
    vec4 illumination = vec4(0.0f);
    vec3 prevPos = vec3(0.0f);

    // Avoid affecting hand
		if(isHand(texture2D(depthtex0, TexCoords).r)) return illumination;

    float PDF = 1.0f / (2.0f * PI);
    vec3 sampleOrigin = viewPos + normal * 0.01f;
    bool intersect;

    for(int i = 0; i < SSGI_SAMPLES; i++) {
        vec3 noise = hash33(vec3(TexCoords, i));
        float cosTheta = 0.0f;
        //Sampling pos
        vec3 sampleDir = normalize(hemisphereSample(noise.x, noise.y, cosTheta)) * SSGI_BIAS;
        float NdotD = dot(normal, sampleDir);

        // Avoids sending rays into the block it started on
        if(NdotD < 0.0f) sampleDir = -sampleDir;

        // Ray trace & Compute color
        intersect = rayTrace(sampleOrigin, sampleDir, prevPos);
        vec4 sampleColor = texture2D(colortex0, prevPos.xy);
        // Temporal Accumulation
        vec2 offset = hash22(prevPos.xy + sin(frameTimeCounter));
        sampleColor += texture2D(colortex0, prevPos.xy + (offset * 2.0f - 1.0f) * 0.005f);

        if(intersect) illumination += sampleColor * cosTheta * NdotD / PDF;
    }

    illumination /= SSGI_SAMPLES;
    return illumination * SSGI_SCALE;
}
