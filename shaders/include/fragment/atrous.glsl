/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

/* 
    SOURCES / CREDITS:
    Jakemichie97:                               - jakemichie97#7237
    Samuel:       https://github.com/swr06      - swr#1793
    L4mbads:                                    - L4mbads#6227
    SixthSurge:   https://github.com/sixthsurge - SixthSurge#3922
    Alain Galvan: https://alain.xyz/blog/ray-tracing-denoising
    Jan Dundr:    https://cescg.org/wp-content/uploads/2018/04/Dundr-Progressive-Spatiotemporal-Variance-Guided-Filtering-2.pdf
*/

float spatialVariance(sampler2D tex) {
    vec2 sum = vec2(0.0); 

    for(int x = -1; x <= 1; x++) {
        for(int y = -1; y <= 1; y++) {
            float luminance = luminance(texture(tex, texCoords + vec2(x, y) * pixelSize).rgb);
            sum            += vec2(luminance, luminance * luminance);
        }
    }
    sum /= 9.0;
    return abs(sum.x * sum.x - sum.y);
}

float spatialVariance() {
    float variance = 0.0;

    for(int x = -1; x <= 1; x++) {
        for(int y = -1; y <= 1; y++) {
            variance += texture(colortex11, texCoords + vec2(x, y) * pixelSize).b * gaussianDistrib2D(vec2(x, y), 1.0);
        }
    }
    return variance;
}

const float aTrous[3] = float[3](1.0, 2.0 / 3.0, 1.0 / 6.0);
const float steps[5]  = float[5](
    ATROUS_STEP_SIZE * 0.0625,
    ATROUS_STEP_SIZE * 0.125,
    ATROUS_STEP_SIZE * 0.25,
    ATROUS_STEP_SIZE * 0.5,
    ATROUS_STEP_SIZE
);

float getATrousNormalWeight(vec3 normal, vec3 sampleNormal) {
    return pow(max0(dot(normal, sampleNormal)), NORMAL_WEIGHT_SIGMA);
}

float getATrousDepthWeight(float depth, float sampleDepth, vec2 dgrad, vec2 offset) {
    return exp(-abs(depth - sampleDepth) / (abs(DEPTH_WEIGHT_SIGMA * dot(dgrad, offset)) + 5e-3));
}

float getATrousLuminanceWeight(float luminance, float sampleLuminance, float variance) {
    return exp(-abs(luminance - sampleLuminance) / (LUMA_WEIGHT_SIGMA * variance + EPS));
}

void aTrousFilter(inout vec3 irradiance, sampler2D tex, vec2 coords, int passIndex) {
    Material mat = getMaterial(coords);
    if(mat.depth0 == 1.0) return;

    float totalWeight = 1.0;
    vec2 stepSize     = steps[passIndex] * pixelSize;

    float frames = float(texture(colortex5, coords).a > 4.0);
    vec2 dgrad   = vec2(dFdx(mat.depth0), dFdy(mat.depth0));

    float centerLuma = luminance(irradiance);
    float variance   = spatialVariance();

    for(int x = -1; x <= 1; x++) {
        for(int y = -1; y <= 1; y++) {
            if(all(equal(ivec2(x,y), ivec2(0)))) continue;

            vec2 offset       = vec2(x, y) * stepSize;
            vec2 sampleCoords = coords + offset;

            if(clamp01(sampleCoords) != sampleCoords) continue;

            Material sampleMat    = getMaterial(sampleCoords);
            vec3 sampleIrradiance = texelFetch(tex, ivec2(sampleCoords * viewSize), 0).rgb;

            float normalWeight = getATrousNormalWeight(mat.normal, sampleMat.normal);
            float depthWeight  = getATrousDepthWeight(mat.depth0, sampleMat.depth0, dgrad, offset);
            float lumaWeight   = mix(1.0, getATrousLuminanceWeight(centerLuma, luminance(sampleIrradiance), variance), frames);

            float weight = clamp01(normalWeight * depthWeight * lumaWeight) * aTrous[abs(x)] * aTrous[abs(y)];
            irradiance  += sampleIrradiance * weight;
            totalWeight += weight;
        }
    }
    irradiance /= totalWeight;
}
