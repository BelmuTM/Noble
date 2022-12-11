/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#if defined STAGE_VERTEX

    flat out float avgLuminance;
    //flat out vec4[HISTOGRAM_BINS / 4] luminanceHistogram;
    //flat out int medianBin;

    #if EXPOSURE == 2
        /*
            SOURCE:
            Alex Tardif - https://www.alextardif.com/HistogramLuminance.html
        */

        const int tiles = 64;
        ivec2 gridSize  = ivec2(viewSize / tiles);
        vec2 tileSize   = 1.0 / gridSize;

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
                    float luminance = luminance(textureLod(colortex4, coords, lod).rgb);

                    pdf[getBinFromLuminance(luminance)] += 1;
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
        gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
        texCoords   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

        #if EXPOSURE > 0
            #if EXPOSURE == 1
                float currLuma = pow2(textureLod(colortex4, vec2(0.5), ceil(log2(maxOf(viewSize)))).a);
            #else
                float[HISTOGRAM_BINS] pdf = buildLuminanceHistogram();
                int closestBinToMedian    = getClosestBinToMedian(pdf);

                //for(int i = 0; i < HISTOGRAM_BINS; i++) luminanceHistogram[i >> 2][i & 3] = pdf[i];

                float currLuma = getLuminanceFromBin(closestBinToMedian);
            #endif

            float prevLuma = texelFetch(colortex8, ivec2(0), 0).a;
                  prevLuma = prevLuma > 0.0 ? prevLuma : currLuma;
                  prevLuma = isnan(prevLuma) || isinf(prevLuma) ? currLuma : prevLuma;

            float exposureTime = currLuma < prevLuma ? EXPOSURE_GROWTH : EXPOSURE_DECAY;
                  avgLuminance = mix(currLuma, prevLuma, exp(-exposureTime * frameTime));
        #endif
    }

#elif defined STAGE_FRAGMENT

    #if DEBUG_HISTOGRAM == 1 && EXPOSURE == 2
        /* RENDERTARGETS: 4,6,8 */

        layout (location = 0) out vec4 color;
        layout (location = 1) out vec3 histogram;
        layout (location = 2) out vec4 history;
    #else
        /* RENDERTARGETS: 4,8 */

        layout (location = 0) out vec4 color;
        layout (location = 1) out vec4 history;
    #endif

    #if TAA == 1
        #include "/include/post/taa.glsl"
    #endif

    flat in float avgLuminance;
    //flat in vec4[HISTOGRAM_BINS / 4] luminanceHistogram;
    //flat in int medianBin;

    const float K =  12.5; // Light meter calibration
    const float S = 100.0; // Sensor sensitivity

    float minExposure = PI  / luminance(sunIlluminance);
    float maxExposure = 0.3 / luminance(moonIlluminance);

    float EV100fromLuminance(float luminance) {
        return log2(luminance * S / K);
    }

    float EV100ToExposure(float EV100) {
        return 1.0 / (1.2 * exp2(EV100));
    }

    /*
    #if DEBUG_HISTOGRAM == 1 && EXPOSURE == 2
        void drawHistogram(out vec3 color, int closestBinToMedian) {
    	    vec2 coords = gl_FragCoord.xy * rcp(debugHistogramSize);

    	    if(all(lessThan(gl_FragCoord.xy, debugHistogramSize))) {
    		    int index = int(HISTOGRAM_BINS * coords.x);
                color     = luminanceHistogram[index >> 2][index & 3] > coords.y ? vec3(1.0, 0.0, 0.0) * max0(1.0 - abs(index - closestBinToMedian)) : vec3(1.0);
    	    }
        }
    #endif
    */

    void main() {
        color = texture(colortex4, texCoords);

        #if TAA == 1
            color.rgb = temporalAntiAliasing(colortex4, colortex8);
        #endif

        history.rgb = color.rgb;

        #if EXPOSURE == 0
            float EV100 = log2(pow2(APERTURE) / (1.0 / SHUTTER_SPEED) * 100.0 / ISO);
            color.a     = EV100ToExposure(EV100);
        #else
            color.a   = EV100ToExposure(EV100fromLuminance(avgLuminance));
            history.a = avgLuminance;

            /*
            #if DEBUG_HISTOGRAM == 1 && EXPOSURE == 2
                drawHistogram(histogram, medianBin);
            #endif
            */
        #endif

        color.a    = clamp(color.a, minExposure, maxExposure);
        color.rgb *= color.a;
    }
#endif
