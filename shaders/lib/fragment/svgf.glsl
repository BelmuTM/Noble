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
    float sampCount = 0.0;

    for(int y = -radius; y <= radius; y++) {
        for(int x = -radius; x <= radius; x++) {
            float samp = luma(texture(tex, coords + vec2(x, x) * pixelSize).rgb);
            sigmaVariancePair += vec2(samp, samp * samp);
            sampCount += 1.0;
        }
    }
    sigmaVariancePair /= sampCount;
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

vec3 SVGF(sampler2D tex, vec3 viewPos, vec3 normal, vec2 coords) {
    vec3 color = vec3(0.0);
    float totalWeight = 0.0;

    float kernelWeights[3] = float[3](1.0, 0.66666666, 0.16666666);

    vec3 currCol = texture(tex, texCoords).rgb;
    viewPos = viewToWorld(viewPos);

    float variance = gaussianVariance(tex, texCoords);

    for(int x = -2; x <= 2; x++) {
        for(int y = -2; y <= 2; y++) {
            vec2 sampleCoords = coords + vec2(x, y) * pixelSize;
            float sampleVariance = gaussianVariance(tex, sampleCoords);
        
            float kernel = kernelWeights[abs(x)] * kernelWeights[abs(y)];
        
            vec3 sampleColor = texture(tex, sampleCoords).rgb;
            vec3 delta = currCol - sampleColor;
            float dist = dot(delta, delta);
            float colorWeight = max(0.0, exp(-dist / 4.8));

            vec3 normalAt = normalize(decodeNormal(texture(colortex1, sampleCoords).xy));
            float normalWeight = pow(saturate(dot(normal, normalAt)), 0.00333);

            vec3 samplePos = viewToWorld(getViewPos(sampleCoords));
            delta = viewPos - samplePos;
            dist = dot(delta, delta);
            float posWeight = max(0.0, exp(-dist / 0.03333));

            float varWeight = 1.0 / max(abs(variance - sampleVariance), 0.001);

            float weight = colorWeight * normalWeight * posWeight * varWeight;
            color += texture(tex, sampleCoords).rgb * weight * kernel;
            totalWeight += weight * kernel;
        }
    }
    return saturate(color / totalWeight);
}
