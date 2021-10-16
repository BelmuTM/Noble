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
            float samp = luma(texture(tex, coords + vec2(x, x) * pixelSize).rgb);
            sigmaVariancePair += vec2(samp, samp * samp);
            SAMPLES++;
        }
    }
    sigmaVariancePair /= SAMPLES;
    return max(0.0, sigmaVariancePair.y - sigmaVariancePair.x * sigmaVariancePair.x);
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

const float cPhi = 0.001;
const float nPhi = 0.03;
const float pPhi = 0.3;

vec3 SVGF(sampler2D tex, vec3 viewPos, vec3 normal, vec2 coords, vec2 direction) {
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

    float centerLuma = luma(currCol);
    float variance = gaussianVariance(tex, texCoords);
    float colorPhi = sqrt(max(1e-7, variance + 1e-8)) * 10.0;

    for(int x = -KERNEL_SIZE; x <= KERNEL_SIZE; x++) {
        for(int y = -KERNEL_SIZE; y <= KERNEL_SIZE; y++) {
            vec2 sampleCoords = coords + (vec2(x, y) * pixelSize);
            float kernel = kernelWeights[abs(x)] * kernelWeights[abs(y)];

            vec3 normalAt = normalize(decodeNormal(texture(colortex1, sampleCoords).xy));
            vec3 delta = normal - normalAt;
            float normalWeight = max(0.0, exp(-dot(delta, delta) / nPhi));

            vec3 samplePos = viewToWorld(getViewPos(sampleCoords));
            delta = viewPos - samplePos;
            float posWeight = max(0.0, exp(-dot(delta, delta) / pPhi));
  
            float sampleLuma = luma(texture(tex, sampleCoords).rgb);
            float lumaWeight = colorPhi * (abs(sampleLuma - centerLuma) / max(centerLuma, max(sampleLuma, 0.01)));
            lumaWeight = exp(-lumaWeight);

            float weight = saturate(normalWeight * posWeight * lumaWeight);
            color += texture(tex, sampleCoords).rgb * weight * kernel;
            totalWeight += weight * kernel;
        }
    }
    return color / max(EPS, totalWeight);
}
