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
        const bool colortex5MipmapEnabled = true;
    */

    flat out float avgLuminance;
    out vec2 textureCoords;

    #if MANUAL_CAMERA == 0 && DEBUG_HISTOGRAM == 1 && EXPOSURE == 2
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
                    float luminance = luminance(textureLod(IRRADIANCE_BUFFER, coords * 0.5, lod).rgb);

                    pdf[getBinFromLuminance(luminance)]++;
                }
            }
            return pdf;
        }

        float getGeometricMeanLuminance(float[HISTOGRAM_BINS] pdf) {
            const float totalSamples = float(tiles.x * tiles.y);

            float cumulativeDensity = 0.0;

            int lowerBound = 0;
            int upperBound = HISTOGRAM_BINS - 1;

            float minDensity = EXPOSURE_IGNORE_DARK           * totalSamples;
            float maxDensity = (1.0 - EXPOSURE_IGNORE_BRIGHT) * totalSamples;

            for (int i = 0; i < HISTOGRAM_BINS; i++, cumulativeDensity += pdf[i]) {
                if (cumulativeDensity >= minDensity) { lowerBound = i; break; }
            }

            cumulativeDensity = 0.0;

            for (int i = 0; i < HISTOGRAM_BINS; i++, cumulativeDensity += pdf[i]) {
                if (cumulativeDensity >= maxDensity) { upperBound = i; break; }
            }

            upperBound = max(upperBound, lowerBound);

            float logStep = logLuminanceRange / float(HISTOGRAM_BINS);

            float weightedSum = 0.0;
            float densitySum  = 0.0;

            for (int i = lowerBound; i <= upperBound; i++) {
                float binDensity = pdf[i];
                float logCenter  = minLogLuminance + (float(i) + 0.5) * logStep;

                weightedSum += binDensity * logCenter;
                densitySum  += binDensity;
            }

            return exp(weightedSum / densitySum);
        }

    #endif

    void main() {
        gl_Position   = vec4(gl_Vertex.xy * 2.0 - 1.0, 1.0, 1.0);
        textureCoords = gl_Vertex.xy;

        #if MANUAL_CAMERA == 0 && EXPOSURE > 0

            #if EXPOSURE == 1
                avgLuminance = luminance(texture(IRRADIANCE_BUFFER, vec2(0.25)).rgb);
            #else

                float[HISTOGRAM_BINS] pdf = buildLuminanceHistogram();

                #if DEBUG_HISTOGRAM == 1
                    for (int i = 0; i < HISTOGRAM_BINS; i++) {
                        // Normalizing the PDF
                        luminanceHistogram[i >> 2][i & 3] = pdf[i] * tileSize.x * tileSize.y;
                    }
                #endif

                avgLuminance = getGeometricMeanLuminance(pdf);

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

        layout (rgba16f) uniform image2D colorimg0;

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
        history.rgb = texture(MAIN_BUFFER, textureCoords).rgb;

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

                    bool isBin     = luminanceHistogram[index >> 2][index & 3] > coords.y * 0.8;
                    vec3 histogram = vec3(1.0) * float(isBin);
                    
                    imageStore(colorimg0, ivec2(gl_FragCoord.xy), vec4(histogram, 0.0));
    	        }
                
            #endif
        #endif
    }
    
#endif
