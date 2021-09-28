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
    return color / SAMPLES;
}

vec4 bokeh(vec2 coords, sampler2D tex, vec2 resolution, int quality, float radius) {
    vec4 color = texture(tex, coords);
    vec2 noise = uniformAnimatedNoise(blueNoise.xy);

    int SAMPLES = 1;
    for(int i = 0; i < quality; i++) {
        for(int j = 0; j < quality; j++) {
            vec2 offset = ((vec2(i, j) + noise) - quality * 0.5) / quality;
            
            if(length(offset) < 0.5) {
                color += texture(tex, coords + ((offset * radius) * resolution));
                SAMPLES++;
            }
        }
    }
    return color / SAMPLES;
}

vec4 radialBlur(vec2 coords, sampler2D tex, vec2 resolution, int quality, float size) {
    vec4 color = texture(tex, texCoords);
    vec2 radius = size / resolution;

    int SAMPLES = 1;
    for(int i = 0; i < quality; i++){
        float d = (i * PI2) / quality;
        vec2 sampleCoords = coords + vec2(sin(d), cos(d)) * radius;
            
        color += texture(tex, sampleCoords);
        SAMPLES++;
    }
    return saturate(color / SAMPLES);
}

const float gaussianWeights49[] = float[](
    0.014692925,
    0.015287874,
    0.015880068,
    0.016467365,
    0.017047564,
    0.017618422,
    0.018177667,
    0.018723012,
    0.019252171,
    0.019762876,
    0.020252889,
    0.020720021,
    0.021162151,
    0.021577234,
    0.021963326,
    0.022318593,
    0.022641326,
    0.022929960,
    0.023183082,
    0.023399442,
    0.023577968,
    0.023717775,
    0.023818168,
    0.023878653,
    0.023898908,
    0.023878653,
    0.023818168,
    0.023717775,
    0.023577968,
    0.023399442,
    0.023183082,
    0.022929960,
    0.022641326,
    0.022318593,
    0.021963326,
    0.021577234,
    0.021162151,
    0.020720021,
    0.020252889,
    0.019762876,
    0.019252171,
    0.018723012,
    0.018177667,
    0.017618422,
    0.017047564,
    0.016467365,
    0.015880068,
    0.015287874,
    0.014692925
);

const float gaussianWeights27[] = float[](
    0.063459680,
    0.062661645,
    0.060328082,
    0.056630230,
    0.051830751,
    0.046252755,
    0.040243823,
    0.034140715,
    0.028239541,
    0.022774771,
    0.017908591,
    0.013730284,
    0.010263800,
    0.007480790,
    0.005316152,
    0.003683482,
    0.002488463,
    0.001639140,
    0.001052722,
    0.000659211,
    0.000402485,
    0.000239602,
    0.000139074,
    0.000078708,
    0.000043432,
    0.000023367,
    0.000012258,
    0.000006270
);

const float gaussianWeights11[] = float[](
	0.019590831,
	0.042587370,
	0.077902496,
	0.119916743,
	0.155336773,
	0.169331570,
	0.155336773,
	0.119916743,
	0.077902496,
	0.042587370,
	0.019590831
);

vec3 gaussianBlur(vec2 coords, sampler2D tex, vec2 direction, float scale) {
    vec3 color = vec3(0.0);

    for(int i = 0; i < 11; i++) {
        vec2 sampleCoords = (coords + (direction * float(i - 5) * pixelSize)) * scale;
        color += texture(tex, sampleCoords).rgb * gaussianWeights11[i];
    }
    return color;
}

float edgeWeight(vec2 sampleCoords, vec3 pos, vec3 normal) { 
    vec3 posAt = getViewPos(sampleCoords);
    vec3 normalAt = normalize(decodeNormal(texture(colortex1, sampleCoords).xy));

    const float posThresh = 0.7;
    const float normalThresh = 0.4;

    return float(
           abs(posAt.x - pos.x) <= posThresh
        && abs(posAt.y - pos.y) <= posThresh
        && abs(posAt.z - pos.z) <= posThresh
        && abs(normalAt.x - normal.x) <= normalThresh
        && abs(normalAt.y - normal.y) <= normalThresh
        && abs(normalAt.z - normal.z) <= normalThresh
        && saturate(sampleCoords) == sampleCoords // Is on screen
    );
}

vec4 heavyGaussianFilter(vec2 coords, vec3 viewPos, vec3 normal, sampler2D tex, vec2 direction) {
    vec4 color = vec4(0.0);
    float totalWeight = 0.0;

    for(int i = -27; i < 27; i++) {
        vec2 sampleCoords = coords + (direction * i * pixelSize);
        float weight = gaussianWeights27[abs(i)] * edgeWeight(sampleCoords, viewPos, normal);

        color += texture(tex, sampleCoords) * weight;
        totalWeight += weight;
    }
    return saturate(color / max(1e-5, totalWeight));
}

vec4 fastGaussianFilter(vec2 coords, vec3 viewPos, vec3 normal, sampler2D tex, vec2 direction) {
    vec4 color = vec4(0.0);
    float totalWeight = 0.0;

    for(int i = 0; i < 11; i++) {
        vec2 sampleCoords = coords + (direction * float(i - 5) * pixelSize);
        float weight = gaussianWeights11[abs(i)] * edgeWeight(sampleCoords, viewPos, normal);

        color += texture(tex, sampleCoords) * weight;
        totalWeight += weight;
    }
    return saturate(color / max(1e-5, totalWeight));
}
