/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
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

float spatialVariance(sampler2D tex, vec2 coords) {
    vec2 sigmaVariancePair = vec2(0.0); int samples = 0;

    for(int x = -1; x <= 1; x++) {
        for(int y = -1; y <= 1; y++, samples++) {

            float luminance    = luminance(texture(colortex5, coords + vec2(x, y) * pixelSize).rgb);
            sigmaVariancePair += vec2(luminance, luminance * luminance);
        }
    }
    sigmaVariancePair /= samples;
    return max0(sigmaVariancePair.y - sigmaVariancePair.x * sigmaVariancePair.x);
}

float gaussianVariance(sampler2D tex, vec2 coords) {
    float variance   = 0.0;
    const int radius = 1;

    for(int x = -radius; x <= radius; x++) {
        for(int y = -radius; y <= radius; y++) {
            variance += texture(tex, coords + vec2(x, y) * pixelSize).z * gaussianDistrib2D(vec2(x, y), 1.0);
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

float getNormalWeight(vec3 normal, vec3 sampleNormal) {
    return pow(max0(dot(normal, sampleNormal)), NORMAL_WEIGHT_SIGMA);
}

float getDepthWeight(float depth, float sampleDepth, vec2 dgrad, vec2 offset) {
    return exp(-abs(linearizeDepth(depth) - linearizeDepth(sampleDepth)) / (abs(DEPTH_WEIGHT_SIGMA * dot(dgrad, offset)) + 0.1));
}

float getLuminanceWeight(float luminance, float sampleLuminance, float luminancePhi) {
    return exp(-abs(luminance - sampleLuminance) * luminancePhi);
}

void aTrousFilter(inout vec3 color, sampler2D tex, vec2 coords, inout vec3 moments, int passIndex) {
    Material mat = getMaterial(coords);
    if(mat.depth1 == 1.0) return;

    float totalWeight = 1.0, totalWeightSquared = 1.0;
    vec2 stepSize     = steps[passIndex] * pixelSize;

    float frames = clamp01(texture(colortex4, coords).a / 4.0);
    vec2 dgrad   = vec2(dFdx(mat.depth1), dFdy(mat.depth1));

    float centerLuma   = luminance(color);
    float variance     = gaussianVariance(colortex12, coords);
    float luminancePhi = 1.0 / (LUMA_WEIGHT_SIGMA * sqrt(variance) + EPS);

    moments = texture(colortex12, texCoords).xyz;

    for(int x = -1; x <= 1; x++) {
        for(int y = -1; y <= 1; y++) {
            vec2 offset        = vec2(x, y) * stepSize;
            vec2 sampleCoords  = coords + offset;

            if(clamp01(sampleCoords) != sampleCoords || all(equal(ivec2(x,y), ivec2(0)))) continue;

            Material sampleMat = getMaterial(sampleCoords);
            vec3 sampleColor   = texelFetch(tex, ivec2(sampleCoords * viewSize), 0).rgb;

            float normalWeight = getNormalWeight(mat.normal, sampleMat.normal);
            float depthWeight  = getDepthWeight(mat.depth1, sampleMat.depth1, dgrad, offset);
            float lumaWeight   = mix(1.0, getLuminanceWeight(centerLuma, luminance(sampleColor), luminancePhi), frames);

            float weight  = aTrous[abs(x)] * aTrous[abs(y)];
                  weight *= normalWeight * depthWeight * lumaWeight;
                  weight  = clamp01(weight);
           
            color              += sampleColor * weight;
            totalWeight        += weight;
            totalWeightSquared += weight * weight;
        }
    }
    color      = color / totalWeight;
    moments.z *= totalWeightSquared;
}
