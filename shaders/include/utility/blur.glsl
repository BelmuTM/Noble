/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec4 boxBlur(vec2 coords, sampler2D tex, int size) {
    vec4 color  = vec4(0.0);
    int samples = 1;

    for(int x = -size; x <= size; x++) {
        for(int y = -size; y <= size; y++) {
            color += texture(tex, coords + vec2(x, y) * pixelSize);
            samples++;
        }
    }
    return color / float(samples);
}

vec4 gaussianBlur(vec2 coords, sampler2D tex, float radius, float sigma, int steps) {
    vec4 color = vec4(0.0);

    for(int x = -steps; x <= steps; x++) {
        for(int y = -steps; y <= steps; y++) {
            float weight = gaussianDistrib2D(vec2(x, y), sigma);
            color       += texture(tex, coords + vec2(x, y) * radius * pixelSize) * weight;
        }
    }
    return color;
}
