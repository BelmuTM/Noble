/********************************************************************************/
/*                                                                              */
/*    Noble Shaders                                                             */
/*    Copyright (C) 2025  Belmu                                                 */
/*                                                                              */
/*    This program is free software: you can redistribute it and/or modify      */
/*    it under the terms of the GNU General Public License as published by      */
/*    the Free Software Foundation, either version 3 of the License, or         */
/*    (at your option) any later version.                                       */
/*                                                                              */
/*    This program is distributed in the hope that it will be useful,           */
/*    but WITHOUT ANY WARRANTY; without even the implied warranty of            */
/*    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the             */
/*    GNU General Public License for more details.                              */
/*                                                                              */
/*    You should have received a copy of the GNU General Public License         */
/*    along with this program.  If not, see <https://www.gnu.org/licenses/>.    */
/*                                                                              */
/********************************************************************************/

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
            return exp(-abs(depth - sampleDepth) / (abs(DEPTH_WEIGHT_SIGMA * dot(depthGradient, offset)) + 0.8));
        }

        float calculateATrousLuminanceWeight(float luminance, float sampleLuminance, float variance) {
            return exp(-abs(luminance - sampleLuminance) / maxEps(LUMINANCE_WEIGHT_SIGMA * sqrt(variance) + 0.1));
        }

        float gaussianVariance(vec2 coords, vec3 normal, float depth, vec2 depthGradient) {
            float varianceSum = 0.0, totalWeight = EPS;
            
            for(int x = -1; x <= 1; x++) {
                for(int y = -1; y <= 1; y++) {
                    vec2  offset       = vec2(x, y) * texelSize;
                    vec2  sampleCoords = coords + offset;

                    if(saturate(sampleCoords) == sampleCoords) {
                        float weight   = gaussianDistribution2D(vec2(x, y), 1.0);
                        float variance = texture(MOMENTS_BUFFER, sampleCoords).b;

                        varianceSum += variance * weight;
                        totalWeight += weight;
                    }
                }
            }
            return (varianceSum / totalWeight) * 5.0;
        }

        void aTrousFilter(sampler2D depthTex, float nearPlane, float farPlane, vec2 coords, inout vec3 irradiance, inout vec3 moments) {
            float depth = texture(depthTex, coords).r;
            if(depth == 1.0) return;

            uvec4 dataTexture = texelFetch(GBUFFERS_DATA, ivec2(gl_FragCoord.xy), 0);
            vec3  normal      = mat3(gbufferModelView) * decodeUnitVector(vec2(dataTexture.w & 65535u, (dataTexture.w >> 16u) & 65535u) * rcpMaxFloat16);

            float accumulatedSamples = texture(ACCUMULATION_BUFFER, coords).a;
            float frameWeight        = float(accumulatedSamples > MIN_FRAMES_LUMINANCE_WEIGHT);

            float linearDepth   = linearizeDepth(depth, nearPlane, farPlane);
            vec2  depthGradient = vec2(dFdx(linearDepth), dFdy(linearDepth));

            float centerLuminance  = luminance(irradiance);
            float filteredVariance = gaussianVariance(coords, normal, depth, depthGradient);

            vec2  stepSize    = ATROUS_STEP_SIZE * pow(0.5, 4 - ATROUS_PASS_INDEX) * texelSize;
            float totalWeight = 1.0;

            for(int x = -1; x <= 1; x++) {
                for(int y = -1; y <= 1; y++) {
                    if(x == 0 && y == 0) continue;

                    vec2 offset       = vec2(x, y) * stepSize;
                    vec2 sampleCoords = coords + offset;

                    if(saturate(sampleCoords) != sampleCoords) continue;

                    ivec2 texelCoords = ivec2(sampleCoords * viewSize * GI_SCALE * 0.01);

                    uvec4 sampleDataTexture = texelFetch(GBUFFERS_DATA, texelCoords, 0);
                    vec3  sampleNormal      = mat3(gbufferModelView) * decodeUnitVector(vec2(sampleDataTexture.w & 65535u, (sampleDataTexture.w >> 16u) & 65535u) * rcpMaxFloat16);
                    float sampleDepth       = texture(depthTex, sampleCoords).r;
                          sampleDepth       = linearizeDepth(sampleDepth, nearPlane, farPlane);

                    vec3  sampleIrradiance = texelFetch(INPUT_BUFFER  , texelCoords, 0).rgb;
                    float sampleVariance   = texelFetch(MOMENTS_BUFFER, texelCoords, 0).b;

                    float normalWeight    = calculateATrousNormalWeight(normal, sampleNormal);
                    float depthWeight     = calculateATrousDepthWeight(linearDepth, sampleDepth, depthGradient, offset);
                    float luminanceWeight = calculateATrousLuminanceWeight(centerLuminance, luminance(sampleIrradiance), filteredVariance);

                    float weight  = normalWeight * depthWeight * mix(1.0, luminanceWeight, frameWeight);
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

            sampler2D depthTex = depthtex0;
            float     depth    = texture(depthtex0, vertexCoords).r;

            float nearPlane = near;
            float farPlane  = far;

            #if defined DISTANT_HORIZONS
                if(depth >= 1.0) {
                    depthTex = dhDepthTex0;

                    nearPlane = dhNearPlane;
                    farPlane  = dhFarPlane;
                }
            #endif

            ivec2 texelCoords = ivec2(gl_FragCoord.xy);

            irradiance = texelFetch(INPUT_BUFFER  , texelCoords, 0);
            moments    = texelFetch(MOMENTS_BUFFER, texelCoords, 0);
            aTrousFilter(depthTex, nearPlane, farPlane, vertexCoords, irradiance.rgb, moments.rgb);
        }
        
    #endif
#else
    #include "/programs/discard.glsl"
#endif
