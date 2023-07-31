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

#include "/include/taau_scale.glsl"
#include "/include/common.glsl"

#if GI == 0 || GI_FILTER == 0 || RENDER_MODE == 1
    #include "/programs/discard.glsl"
#else
    #if defined STAGE_VERTEX
        #include "/programs/vertex_taau.glsl"

    #elif defined STAGE_FRAGMENT

        #if ATROUS_PASS_INDEX <= 0
            #define INPUT_BUFFER LIGHTING_BUFFER
        #else
            #define INPUT_BUFFER MAIN_BUFFER
        #endif

        #if ATROUS_PASS_INDEX == 0
            /* RENDERTARGETS: 0 */

            layout (location = 0) out vec4 irradiance;
        #else
            /* RENDERTARGETS: 0 */

            layout (location = 0) out vec4 irradiance;
        #endif

        in vec2 textureCoords;
        in vec2 vertexCoords;

        const float aTrous[3] = float[3](1.0, 2.0 / 3.0, 1.0 / 6.0);
        const float steps[5]  = float[5](
            ATROUS_STEP_SIZE * 0.0625,
            ATROUS_STEP_SIZE * 0.125,
            ATROUS_STEP_SIZE * 0.25,
            ATROUS_STEP_SIZE * 0.5,
            ATROUS_STEP_SIZE
        );

        float calculateATrousNormalWeight(vec3 normal, vec3 sampleNormal) {   
            return pow(max0(dot(normal, sampleNormal)), NORMAL_WEIGHT_SIGMA);
        }

        float calculateATrousDepthWeight(float depth, float sampleDepth, vec2 depthGradient, vec2 offset) {
            return exp(-abs(depth - sampleDepth) / (abs(DEPTH_WEIGHT_SIGMA * dot(depthGradient, offset)) + 5e-3));
        }

        float calculateATrousLuminanceWeight(float luminance, float sampleLuminance, float variance) {
            return exp(-abs(luminance - sampleLuminance) / maxEps(LUMINANCE_WEIGHT_SIGMA * variance));
        }

        float spatialVariance(vec2 coords, Material material, vec2 depthGradient) {
            float sum = 0.0, sqSum = 0.0, totalWeight = 1.0;

            int  filterSize = 3;
            vec2 stepSize   = steps[ATROUS_PASS_INDEX] * pixelSize;

            for(int x = -filterSize; x <= filterSize; x++) {
                for(int y = -filterSize; y <= filterSize; y++) {
                    float weight       = gaussianDistribution2D(vec2(x, y), 1.0);
                    vec2  offset       = vec2(x, y) * stepSize;
                    vec2  sampleCoords = coords + offset;

                    if(saturate(sampleCoords) != sampleCoords) continue;

                    Material sampleMaterial = getMaterial(sampleCoords);

                    float normalWeight = calculateATrousNormalWeight(material.normal, sampleMaterial.normal);
                    float depthWeight  = calculateATrousDepthWeight(material.depth0, sampleMaterial.depth0, depthGradient, offset);

                    weight = saturate(weight) * aTrous[abs(x)] * aTrous[abs(y)];

                    float luminance = luminance(texture(INPUT_BUFFER, sampleCoords).rgb);

                    sum   += luminance * weight;
                    sqSum += luminance * luminance * weight;

                    totalWeight += weight;
                }
            }
            sum   /= totalWeight;
            sqSum /= totalWeight;
            return sqrt(max0(sqSum - (sum * sum)));
        }

        float temporalVariance(vec2 coords) {
            float sum = 0.0, sqSum = 0.0, totalWeight = 1.0;

            int filterSize = 1;

            for(int x = -filterSize; x <= filterSize; x++) {
                for(int y = -filterSize; y <= filterSize; y++) {
                    float weight      = gaussianDistribution2D(vec2(x, y), 1.0);
                    float luminanceSq = texture(TEMPORAL_DATA_BUFFER, coords + vec2(x, y) * pixelSize).r;
                    
                    sum   += sqrt(luminanceSq) * weight;
                    sqSum += luminanceSq       * weight;

                    totalWeight += weight;
                }
            }
            sum   /= totalWeight;
            sqSum /= totalWeight;
            return sqrt(max0(sqSum - (sum * sum)));
        }

        void aTrousFilter(inout vec3 irradiance, vec2 coords) {
            Material material = getMaterial(coords);
            if(material.depth0 == 1.0) return;

            vec2 depthGradient = vec2(dFdx(material.depth0), dFdy(material.depth0));

            float totalWeight = 1.0;
            vec2 stepSize     = steps[ATROUS_PASS_INDEX] * pixelSize;

            float accumulatedSamples = texture(LIGHTING_BUFFER, textureCoords).a;

            float frameWeight = float(accumulatedSamples > 4.0);

            float centerLuminance = luminance(irradiance);
            float variance        = accumulatedSamples < 128.0 ? spatialVariance(coords, material, depthGradient) : temporalVariance(coords);

            for(int x = -1; x <= 1; x++) {
                for(int y = -1; y <= 1; y++) {
                    if(all(equal(ivec2(x,y), ivec2(0)))) continue;

                    vec2 offset       = vec2(x, y) * stepSize;
                    vec2 sampleCoords = coords + offset;

                    if(saturate(sampleCoords) != sampleCoords) continue;

                    Material sampleMaterial = getMaterial(sampleCoords);
                    vec3 sampleIrradiance   = texture(INPUT_BUFFER, sampleCoords).rgb;

                    float normalWeight    = calculateATrousNormalWeight(material.normal, sampleMaterial.normal);
                    float depthWeight     = calculateATrousDepthWeight(material.depth0, sampleMaterial.depth0, depthGradient, offset);
                    float luminanceWeight = calculateATrousLuminanceWeight(centerLuminance, luminance(sampleIrradiance), variance);

                    float weight = saturate(normalWeight * depthWeight * mix(1.0, luminanceWeight, frameWeight) * aTrous[abs(x)] * aTrous[abs(y)]);
                    irradiance  += sampleIrradiance * weight;
                    totalWeight += weight;
                }
            }
            irradiance /= totalWeight;
        }

        void main() {
            irradiance = texture(INPUT_BUFFER, vertexCoords);
            aTrousFilter(irradiance.rgb, vertexCoords);
        }
    #endif
#endif
