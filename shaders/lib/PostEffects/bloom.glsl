/*
  Author: Belmu (https://github.com/BelmuTM/)
  */

vec4 computeBloom(vec3 color, int widthMultiplier, int heightMultiplier) {
    vec4 bloom = vec4(0.0f);

    int SAMPLES;
    for(int i = -widthMultiplier ; i <= widthMultiplier; i++) {
        for(int j = -heightMultiplier; j <= heightMultiplier; j++)
            bloom += texture2D(colortex0, TexCoords + vec2((j * 1.0f / viewWidth), (i * 1.0f / viewHeight)));
            SAMPLES++;
    }
    bloom /= SAMPLES;

    return bloom;
}
