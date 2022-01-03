/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec4 boxBlur(vec2 coords, sampler2D tex, int size) {
    vec4 color  = vec4(0.0);
    int SAMPLES = 1;

    for(int x = -size; x <= size; x++) {
        for(int y = -size; y <= size; y++) {
            color += texture(tex, coords + vec2(x, y) * pixelSize);
            SAMPLES++;
        }
    }
    return color / float(SAMPLES);
}

vec4 gaussianBlur(vec2 coords, sampler2D tex, float radius, float sigma, int steps) {
    vec4 color = vec4(0.0);

    for(int i = -steps; i <= steps; i++) {
        for(int j = -steps; j <= steps; j++) {
            float weight = gaussianDistrib1D(i, sigma) * gaussianDistrib1D(j, sigma);
            color       += texture(tex, coords + vec2(i, j) * radius * pixelSize) * weight;
        }
    }
    return color;
}
