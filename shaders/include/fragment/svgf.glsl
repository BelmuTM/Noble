/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

float computeVariance(sampler2D tex, vec2 coords) {
    const int radius = 2; // 5x5 kernel
    vec2 sigmaVariancePair = vec2(0.0);

    int SAMPLES;
    for(int y = -radius; y <= radius; y++) {
        for(int x = -radius; x <= radius; x++) {
            float samp = luminance(texture(tex, coords + vec2(x, x) * pixelSize).rgb);
            sigmaVariancePair += vec2(samp, samp * samp);
            SAMPLES++;
        }
    }
    sigmaVariancePair /= SAMPLES;
    return max0(sigmaVariancePair.y - sigmaVariancePair.x * sigmaVariancePair.x);
}

float gaussianVariance(sampler2D tex, vec2 coords) {
    float sum = 0.0;
    const mat2 kernel = mat2(
        0.25,  0.125,
        0.125, 0.0625
    );

    const int radius = 1;
    for(int x = -radius; x <= radius; x++) {
        for(int y = -radius; y <= radius; y++) {

            vec2 p = coords + vec2(x, y) * pixelSize;
            float k = kernel[abs(x)][abs(y)];
            sum += computeVariance(tex, p) * k;
        }
    }
    return sum;
}

const float cPhi = 0.01;
const float nPhi = 0.05;
const float pPhi = 0.02;

vec3 SVGF(sampler2D tex, vec3 viewPos, vec3 normal, vec2 coords) {
    vec3 color = vec3(0.0);
    float totalWeight = 0.0;

    const int KERNEL_SIZE = 3;
    float kernelWeights[] = float[](
        0.233642855,
        0.200015531,
        0.125480758,
        0.057682282
    );

    vec3 currCol = texture(tex, texCoords).rgb;
    viewPos = viewToWorld(viewPos);

    float centerLuma = luminance(currCol);
    float variance = gaussianVariance(tex, texCoords);
    float colorPhi = sqrt(max(1e-7, variance + 1e-8)) * 2.0;

    for(int x = -KERNEL_SIZE; x <= KERNEL_SIZE; x++) {
        for(int y = -KERNEL_SIZE; y <= KERNEL_SIZE; y++) {
            vec2 sampleCoords = coords + (vec2(x, y) * pixelSize);
            float kernel = kernelWeights[x] * kernelWeights[y];

            vec3 normalAt = normalize(decodeNormal(texture(colortex1, sampleCoords).xy));
            vec3 delta = viewToWorld(normal) -  viewToWorld(normalAt);
            float normalWeight = max0(exp(-dot(delta, delta) / nPhi));

            vec3 samplePos = viewToWorld(getViewPos(sampleCoords));
            delta = viewPos - samplePos;
            float posWeight = max0(exp(-dot(delta, delta) / pPhi));
  
            float sampleLuma = luminance(texture(tex, sampleCoords).rgb);
            float lumaWeight = colorPhi * (exp(-(abs(sampleLuma - centerLuma) / max(sampleLuma, max(centerLuma, TAA_LUMA_MIN)))));

            float weight = normalWeight * posWeight * lumaWeight;
            color += texture(tex, sampleCoords).rgb * weight * kernel;
            totalWeight += weight * kernel;
        }
    }
    return color / maxEps(totalWeight);
}
