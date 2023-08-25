/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

/*
    [Credits]:
        Jakemichie97 (https://twitter.com/jakemichie97)
        Samuel (https://github.com/swr06)
        L4mbads (L4mbads#6227)
        SixthSurge (https://github.com/sixthsurge)
        
    [References]:
        Galvan, A. (2020). Ray Tracing Denoising. https://alain.xyz/blog/ray-tracing-denoising
        Dundr, J. (2018). Progressive Spatiotemporal Variance-Guided Filtering. https://cescg.org/wp-content/uploads/2018/04/Dundr-Progressive-Spatiotemporal-Variance-Guided-Filtering-2.pdf
*/

#include "/settings.glsl"

#if RENDER_MODE == 0 && GI == 1 && ATROUS_FILTER == 1
    #include "/include/taau_scale.glsl"

    #if defined STAGE_VERTEX
        #include "/programs/vertex_taau.glsl"

    #elif defined STAGE_FRAGMENT

        #if ATROUS_PASS_INDEX <= 0
            #define INPUT_BUFFER ACCUMULATION_BUFFER
        #else
            #define INPUT_BUFFER DEFERRED_BUFFER
        #endif

        #if ATROUS_PASS_INDEX == 0
            /* RENDERTARGETS: 10,13 */

            layout (location = 0) out vec4 moments;
            layout (location = 1) out vec4 irradiance;
        #else
            /* RENDERTARGETS: 10,13 */

            layout (location = 0) out vec4 moments;
            layout (location = 1) out vec4 irradiance;
        #endif

        in vec2 textureCoords;
        in vec2 vertexCoords;

        #include "/include/common.glsl"

        const float waveletKernel[3] = float[3](1.0, 2.0 / 3.0, 1.0 / 6.0);

        float calculateATrousNormalWeight(vec3 normal, vec3 sampleNormal) {   
            return pow(max0(dot(normal, sampleNormal)), NORMAL_WEIGHT_SIGMA);
        }

        float calculateATrousDepthWeight(float depth, float sampleDepth, vec2 depthGradient, vec2 offset) {
            return exp(-abs(linearizeDepthFast(depth) - linearizeDepthFast(sampleDepth)) / (abs(DEPTH_WEIGHT_SIGMA * dot(depthGradient, offset)) + 0.1));
        }

        float calculateATrousLuminanceWeight(float luminance, float sampleLuminance, float variance) {
            return exp(-abs(luminance - sampleLuminance) / maxEps(LUMINANCE_WEIGHT_SIGMA * sqrt(variance)));
        }

        float gaussianVariance(vec2 coords, vec3 normal, float depth, vec2 depthGradient) {
            float varianceSum = 0.0, totalWeight = EPS;

            int filterSize = 3;
            
            for(int x = -filterSize; x <= filterSize; x++) {
                for(int y = -filterSize; y <= filterSize; y++) {
                    vec2  offset       = vec2(x, y) * texelSize;
                    vec2  sampleCoords = coords + offset;

                    if(saturate(sampleCoords) != sampleCoords) continue;

                    float weight   = saturate(gaussianDistribution2D(vec2(x, y), 1.0));
                    float variance = texture(MOMENTS_BUFFER, sampleCoords).b;

                    varianceSum += variance * weight;
                    totalWeight += weight;
                }
            }
            return varianceSum / totalWeight;
        }

        void aTrousFilter(inout vec3 irradiance, inout vec3 moments, vec2 coords) {
            Material material = getMaterial(coords);
            if(material.depth0 == 1.0) return;

            float accumulatedSamples = texture(ACCUMULATION_BUFFER, coords).a;
            float frameWeight        = float(accumulatedSamples > MIN_FRAMES_LUMINANCE_WEIGHT);

            float linearDepth   = linearizeDepthFast(material.depth0);
            vec2  depthGradient = vec2(dFdx(linearDepth), dFdy(linearDepth));

            float centerLuminance  = luminance(irradiance);
            float filteredVariance = gaussianVariance(coords, material.normal, material.depth0, depthGradient);

            vec2  stepSize    = ATROUS_STEP_SIZE * pow(0.5, 4 - ATROUS_PASS_INDEX) * texelSize;
            float totalWeight = 1.0;

            for(int x = -1; x <= 1; x++) {
                for(int y = -1; y <= 1; y++) {
                    if(x == 0 && y == 0) continue;

                    vec2 offset       = vec2(x, y) * stepSize;
                    vec2 sampleCoords = coords + offset;

                    if(saturate(sampleCoords) != sampleCoords) continue;

                    Material sampleMaterial   = getMaterial(sampleCoords);
                    vec3     sampleIrradiance = texture(INPUT_BUFFER  , sampleCoords).rgb;
                    float    sampleVariance   = texture(MOMENTS_BUFFER, sampleCoords).b;

                    float normalWeight    = calculateATrousNormalWeight(material.normal, sampleMaterial.normal);
                    float depthWeight     = calculateATrousDepthWeight(material.depth0, sampleMaterial.depth0, depthGradient, offset);
                    float luminanceWeight = calculateATrousLuminanceWeight(centerLuminance, luminance(sampleIrradiance), filteredVariance);

                    float weight  = saturate(normalWeight * depthWeight * mix(1.0, luminanceWeight, frameWeight));
                          weight *= waveletKernel[abs(x)] * waveletKernel[abs(y)];

                    irradiance  += sampleIrradiance * weight;
                    moments.b   += sampleVariance   * weight * weight;
                    totalWeight += weight;
                }
            }
            irradiance /= totalWeight;
            moments.b  /= (totalWeight * totalWeight);
        }

        void main() {
            vec2 fragCoords = gl_FragCoord.xy * texelSize / RENDER_SCALE;
	        if(saturate(fragCoords) != fragCoords) { discard; return; }

            irradiance = texture(INPUT_BUFFER  , vertexCoords);
            moments    = texture(MOMENTS_BUFFER, vertexCoords);
            aTrousFilter(irradiance.rgb, moments.rgb, vertexCoords);
        }
    #endif
#else
    #include "/programs/discard.glsl"
#endif
