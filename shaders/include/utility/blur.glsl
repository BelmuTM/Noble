/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec4 boxBlur(vec2 coords, sampler2D tex, int size) {
    vec4 color = texture(tex, coords);

    int SAMPLES = 1;
    for(int x = -size; x <= size; x++) {
        for(int y = -size; y <= size; y++) {
            vec2 offset = vec2(x, y) * pixelSize;
            color += texture(tex, coords + offset);
            SAMPLES++;
        }
    }
    return color / float(SAMPLES);
}

const float gaussianWeights7[] = float[](
    0.197447467,
    0.174697346,
    0.120998845,
    0.065602331,
    0.027839605,
    0.009246250,
    0.002403157,
    0.000488728
);

const float gaussianWeights6[] = float[](
	0.169331570,
	0.155336773,
	0.119916743,
	0.077902496,
	0.042587370,
	0.019590831
);

const float gaussianWeights4[] = float[](
    0.188688218,
    0.174474220,
    0.137939336,
    0.093242334
);

vec4 onePassGaussianBlur(vec2 coords, sampler2D tex, vec2 direction, float scale) {
    vec4 color = vec4(0.0);
    const int KERNEL_SIZE = 6;

    for(int i = -KERNEL_SIZE; i < KERNEL_SIZE; i++) {
        vec2 sampleCoords = (coords + (direction * abs(i) * pixelSize)) * scale;
        color            += texture(tex, sampleCoords) * gaussianWeights6[abs(i)];
    }
    return color;
}

vec4 twoPassGaussianBlur(vec2 coords, sampler2D tex, float scale) {
    vec4 color = vec4(0.0);
    const int KERNEL_SIZE = 7;

    for(int x = -KERNEL_SIZE; x < KERNEL_SIZE; x++) {
        for(int y = -KERNEL_SIZE; y < KERNEL_SIZE; y++) {
            vec2 sampleCoords = (coords + (vec2(x, y) * pixelSize)) * scale;
            float kernel      = gaussianWeights7[abs(x)] * gaussianWeights7[abs(y)];

            color += texture(tex, sampleCoords) * kernel;
        }
    }
    return color;
}
