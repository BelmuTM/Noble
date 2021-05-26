/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

vec4 Bloom(vec3 color, int widthMultiplier, int heightMultiplier) {
    vec4 bloom = vec4(0.0);

    int SAMPLES;
    for(int i = -widthMultiplier ; i <= widthMultiplier; i++) {
        for(int j = -heightMultiplier; j <= heightMultiplier; j++)
            bloom += texture2D(colortex0, texCoords + vec2((j * 1.0 / viewWidth), (i * 1.0 / viewHeight)));
            SAMPLES++;
    }
    bloom /= SAMPLES;

    return bloom;
}
