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

#include "/settings.glsl"
#include "/include/taau_scale.glsl"

#include "/include/common.glsl"

#if defined STAGE_VERTEX

    /*
        const bool colortex3MipmapEnabled = true;
    */

    flat out float avgLuminance;
    out vec2 textureCoords;

    #if MANUAL_CAMERA == 0 && DEBUG_HISTOGRAM == 1 && EXPOSURE == 2
        flat out int medianBin;
        flat out vec4[HISTOGRAM_BINS / 4] luminanceHistogram;
    #endif

    #if MANUAL_CAMERA == 0 && EXPOSURE == 2

        ivec2 tiles    = ivec2(floor(32.0 * vec2(1.0, aspectRatio)));
        vec2  tileSize = 1.0 / tiles;

        int getBinFromLuminance(float luminance) {
            if (luminance <= 0) return 0;

    	    return int(clamp((log(luminance) * rcpLogLuminanceRange - (minLogLuminance * rcpLogLuminanceRange)) * HISTOGRAM_BINS, 0, HISTOGRAM_BINS - 1));
        }

        float getLuminanceFromBin(int bin) {
            return exp((bin * rcp(HISTOGRAM_BINS)) * logLuminanceRange + minLogLuminance);
        }

        float[HISTOGRAM_BINS] buildLuminanceHistogram() {
            float lod = ceil(log2(maxOf(viewSize * tileSize)));

            float[HISTOGRAM_BINS] pdf;
            for (int i = 0; i < HISTOGRAM_BINS; i++) pdf[i] = 0.0;

            for (int x = 0; x < tiles.x; x++) {
                for (int y = 0; y < tiles.y; y++) {
                    vec2 coords     = vec2(x, y) * tileSize + tileSize * 0.5;
                    float luminance = luminance(textureLod(ILLUMINANCE_BUFFER, coords * 0.5, lod).rgb);

                    pdf[getBinFromLuminance(luminance)]++;
                }
            }
            for (int i = 0; i < HISTOGRAM_BINS; i++) pdf[i] *= tileSize.x * tileSize.y;
            return pdf;
        }

        int getClosestBinToMedian(float[HISTOGRAM_BINS] pdf) {
            float cumulativeDensity = 0.0;
            vec2 closestBinToMedian = vec2(0.0, 1.0); // vec2(bin, dist)

            // Binary search to find the closest bin to the median (CDF = 0.5)
            for (int i = 0; i < HISTOGRAM_BINS; i++, cumulativeDensity += pdf[i]) {
                float distToMedian = distance(cumulativeDensity, 0.5);
                closestBinToMedian = distToMedian < closestBinToMedian.y ? vec2(i, distToMedian) : closestBinToMedian;
            }
            return int(closestBinToMedian.x);
        }

    #endif

    void main() {
        gl_Position   = vec4(gl_Vertex.xy * 2.0 - 1.0, 1.0, 1.0);
        textureCoords = gl_Vertex.xy;

        #if MANUAL_CAMERA == 0 && EXPOSURE > 0
            #if EXPOSURE == 1
                avgLuminance = luminance(texture(ILLUMINANCE_BUFFER, vec2(0.25)).rgb);
            #else
                float[HISTOGRAM_BINS] pdf = buildLuminanceHistogram();
                int closestBinToMedian    = getClosestBinToMedian(pdf);

                #if DEBUG_HISTOGRAM == 1
                    medianBin = closestBinToMedian;
                    for (int i = 0; i < HISTOGRAM_BINS; i++) luminanceHistogram[i >> 2][i & 3] = pdf[i];
                #endif

                avgLuminance = getLuminanceFromBin(closestBinToMedian);
            #endif

            float prevLuminance = texelFetch(HISTORY_BUFFER, ivec2(0), 0).a;
                  prevLuminance = prevLuminance > 0.0 ? prevLuminance : avgLuminance;
                  prevLuminance = isnan(prevLuminance) || isinf(prevLuminance) ? avgLuminance : prevLuminance;

            float exposureSpeed = avgLuminance < prevLuminance ? EXPOSURE_GROWTH : EXPOSURE_DECAY;
            
            avgLuminance = mix(avgLuminance, prevLuminance, exp(-exposureSpeed * frameTime));
        #endif
    }

#elif defined STAGE_FRAGMENT

    #if MANUAL_CAMERA == 0 && DEBUG_HISTOGRAM == 1 && EXPOSURE == 2

        /* RENDERTARGETS: 8 */

        layout (location = 0) out vec4 history;

        layout (rgba8) uniform image2D colorimg0;

        flat in int medianBin;
        flat in vec4[HISTOGRAM_BINS / 4] luminanceHistogram;

    #else

        /* RENDERTARGETS: 8 */

        layout (location = 0) out vec4 history;

    #endif

    flat in float avgLuminance;
    in vec2 textureCoords;

    #if TAA == 1
        #include "/include/post/exposure.glsl"
    #endif

    void main() {
        history.rgb = logLuvDecode(texture(MAIN_BUFFER, textureCoords));

        #if TAA == 1
            history.rgb *= computeExposure(avgLuminance);
            history.rgb  = reinhard(history.rgb);
        #endif

        #if MANUAL_CAMERA == 0 && EXPOSURE > 0
            history.a = avgLuminance;

            #if DEBUG_HISTOGRAM == 1 && EXPOSURE == 2

    	        if (all(lessThan(gl_FragCoord.xy, debugHistogramSize))) {
                    vec2 coords = gl_FragCoord.xy * rcp(debugHistogramSize);
    		        int index   = int(HISTOGRAM_BINS * coords.x);

                    bool isBin = luminanceHistogram[index >> 2][index & 3] > coords.y * 0.8;

                    vec3 histogram = isBin ? vec3(1.0, 0.0, 0.0) * max0(1.0 - abs(index - medianBin)) : vec3(1.0);
                    
                    imageStore(colorimg0, ivec2(gl_FragCoord.xy), logLuvEncode(histogram));
    	        }
                
            #endif
        #endif
    }
    
#endif
