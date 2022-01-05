/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

float computeVariance(sampler2D tex, vec2 coords) {
    const int radius       = 2; // 5x5 kernel
    vec2 sigmaVariancePair = vec2(0.0);

    int SAMPLES;
    for(int y = -radius; y <= radius; y++) {
        for(int x = -radius; x <= radius; x++) {
            float samp         = luminance(texture(tex, coords + vec2(x, x) * pixelSize).rgb);
            sigmaVariancePair += vec2(samp, pow2(samp));
            SAMPLES++;
        }
    }
    sigmaVariancePair /= SAMPLES;
    return max0(sigmaVariancePair.y - sigmaVariancePair.x * sigmaVariancePair.x);
}

float gaussianVariance(sampler2D tex, vec2 coords, int radius) {
    float variance = 0.0, totalWeight = 0.0;

    for(int i = -radius; i <= radius; i++) {
        for(int j = -radius; j <= radius; j++) {
            float weight = gaussianDistrib2D(vec2(i, j), 2.0);

            variance    += computeVariance(tex, coords + vec2(i, j) * pixelSize) * weight;
            totalWeight += weight;
        }
    }
    return variance / totalWeight;
}

const float cPhi = 1e-2;
const float nPhi = 1e-2;
const float pPhi = 1e-2;

vec3 SVGF(vec2 coords, sampler2D tex, vec3 viewPos, vec3 normal, float sigma, int steps) {
    vec3 color        = vec3(0.0);
    float totalWeight = 0.0;

    vec3 currCol = texture(tex, texCoords).rgb;
    viewPos      = viewToWorld(viewPos);

    float centerLuma = luminance(currCol);
    float variance   = gaussianVariance(tex, texCoords, 1);
    float colorPhi   = sqrt(max(1e-7, variance + 1e-8)) * 2.0;

    for(int i = -steps; i <= steps; i++) {
        for(int j = -steps; j <= steps; j++) {
            vec2 sampleCoords = coords + (vec2(i, j) * pixelSize);
            float gaussian    = gaussianDistrib1D(i, sigma) * gaussianDistrib1D(j, sigma);

            vec3 normalAt = normalize(decodeNormal(texture(colortex1, sampleCoords).xy));
            vec3 delta = viewToWorld(normal) -  viewToWorld(normalAt);
            float normalWeight = max0(exp(-dot(delta, delta) / nPhi));

            vec3 samplePos = viewToWorld(getViewPos0(sampleCoords));
            delta = viewPos - samplePos;
            float posWeight = max0(exp(-dot(delta, delta) / pPhi));
  
            float sampleLuma = luminance(texture(tex, sampleCoords).rgb);
            float lumaWeight = colorPhi * (exp(-(abs(sampleLuma - centerLuma) / max(sampleLuma, max(centerLuma, TAA_LUMA_MIN)))));

            float weight = normalWeight * posWeight * lumaWeight;
            color       += texture(tex, sampleCoords).rgb * weight * gaussian;
            totalWeight += weight * gaussian;
        }
    }
    return color / totalWeight;
}
