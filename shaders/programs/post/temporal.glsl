/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/include/common.glsl"

#if defined STAGE_VERTEX

    flat out float avgLuminance;

    #if DEBUG_HISTOGRAM == 1 && EXPOSURE == 2
        flat out int medianBin;
        flat out vec4[HISTOGRAM_BINS / 4] luminanceHistogram;
    #endif

    #if EXPOSURE == 2
        /*
            SOURCE:
            Alex Tardif - https://www.alextardif.com/HistogramLuminance.html
        */

        ivec2 gridSize = ivec2(viewSize / vec2(64, 32));
        vec2 tileSize  = 1.0 / gridSize;

        int getBinFromLuminance(float luminance) {
    	    return luminance < EPS ? 0 : int(clamp((log(luminance) * rcpLuminanceRange - (minLuminance * rcpLuminanceRange)) * HISTOGRAM_BINS, 0, HISTOGRAM_BINS - 1));
        }

        float getLuminanceFromBin(int bin) {
            return exp((bin * rcp(HISTOGRAM_BINS)) * luminanceRange + minLuminance);
        }

        float[HISTOGRAM_BINS] buildLuminanceHistogram() {
            float lod = ceil(log2(maxOf(viewSize * tileSize)));

            float[HISTOGRAM_BINS] pdf;
            for(int i = 0; i < HISTOGRAM_BINS; i++) pdf[i] = 0.0;

            for(int x = 0; x < gridSize.x; x++) {
                for(int y = 0; y < gridSize.y; y++) {
                    vec2 coords     = vec2(x, y) * tileSize + tileSize * 0.5;
                    float luminance = pow2(textureLod(MAIN_BUFFER, coords, lod).a);

                    pdf[getBinFromLuminance(luminance)]++;
                }
            }
            for(int i = 0; i < HISTOGRAM_BINS; i++) pdf[i] *= tileSize.x * tileSize.y;
            return pdf;
        }

        int getClosestBinToMedian(float[HISTOGRAM_BINS] pdf) {
            float cumulativeDensity = 0.0;
            vec2 closestBinToMedian = vec2(0.0, 1.0); // vec2(bin, dist)

            // Binary search to find the closest bin to the median (CDF = 0.5)
            for(int i = 0; i < HISTOGRAM_BINS; i++, cumulativeDensity += pdf[i]) {
                float distToMedian = distance(cumulativeDensity, 0.5);
                closestBinToMedian = distToMedian < closestBinToMedian.y ? vec2(i, distToMedian) : closestBinToMedian;
            }
            return int(closestBinToMedian.x);
        }
    #endif

    void main() {
        gl_Position   = gl_ModelViewProjectionMatrix * gl_Vertex;
        textureCoords = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

        #if EXPOSURE > 0
            #if EXPOSURE == 1
                float avgLuma = pow2(textureLod(MAIN_BUFFER, vec2(0.5), ceil(log2(maxOf(viewSize)))).a);
            #else
                float[HISTOGRAM_BINS] pdf = buildLuminanceHistogram();
                int closestBinToMedian    = getClosestBinToMedian(pdf);

                #if DEBUG_HISTOGRAM == 1
                    medianBin = closestBinToMedian;
                    for(int i = 0; i < HISTOGRAM_BINS; i++) luminanceHistogram[i >> 2][i & 3] = pdf[i];
                #endif

                float avgLuma = getLuminanceFromBin(closestBinToMedian);
            #endif

            float prevLuma = texelFetch(HISTORY_BUFFER, ivec2(0), 0).a;
                  prevLuma = prevLuma > 0.0 ? prevLuma : avgLuma;
                  prevLuma = isnan(prevLuma) || isinf(prevLuma) ? avgLuma : prevLuma;

            float exposureTime = avgLuma < prevLuma ? EXPOSURE_GROWTH : EXPOSURE_DECAY;
                  avgLuminance = mix(avgLuma, prevLuma, exp(-exposureTime * frameTime));
        #endif
    }

#elif defined STAGE_FRAGMENT

    /* RENDERTARGETS: 0,8 */

    layout (location = 0) out vec4 color;
    layout (location = 1) out vec4 history;

    flat in float avgLuminance;

    #if DEBUG_HISTOGRAM == 1 && EXPOSURE == 2
        flat in int medianBin;
        flat in vec4[HISTOGRAM_BINS / 4] luminanceHistogram;
    #endif

    #if TAA == 1
        #include "/include/utility/sampling.glsl"
        #include "/include/post/taa.glsl"
    #endif

    void main() {
        color = texture(MAIN_BUFFER, textureCoords);

        #if TAA == 1
            color.rgb = temporalAntiAliasing(MAIN_BUFFER, HISTORY_BUFFER);
        #endif

        history.rgb = color.rgb;

        #if EXPOSURE > 0
            history.a = avgLuminance;
            color.a   = avgLuminance;

            #if DEBUG_HISTOGRAM == 1 && EXPOSURE == 2
    	        vec2 coords = gl_FragCoord.xy * rcp(debugHistogramSize);

    	        if(all(lessThan(gl_FragCoord.xy, debugHistogramSize))) {
    		        int index = int(HISTOGRAM_BINS * coords.x);
                    color.rgb = luminanceHistogram[index >> 2][index & 3] > coords.y ? vec3(1.0, 0.0, 0.0) * max0(1.0 - abs(index - medianBin)) : vec3(1.0);
    	        }
            #endif
        #endif
    }
#endif
