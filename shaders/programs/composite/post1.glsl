/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#ifdef STAGE_VERTEX

    out float avgLuminance;

    #define HISTOGRAM_BINS 128

    const ivec2 tiles   = ivec2(64);
    const vec2 tileSize = 1.0 / tiles;

    int getBinFromLuminance(float luminance) {
        if(luminance < EPS) return 0;

        return clamp(int(log(luminance) * histogram_log_scale + histogram_log_zero), 0, HISTOGRAM_BINS - 1);
    }

    float getLuminanceFromBin(int bin) {

    }

    int[HISTOGRAM_BINS] buildLuminanceHistogram() {
        float lod = ceil(log2(maxOf(viewSize * tileSize)));

        int pdf[HISTOGRAM_BINS];
        for(int i = 0; i < HISTOGRAM_BINS; i++) pdf[i] = 0;

        for(int x = 0; x <= tiles.x; x++) {
            for(int y = 0; y <= tiles.y; y++) {
                vec2 coords     = vec2(x, y) * tileSize + tileSize * 0.5;
                float luminance = luminance(textureLod(colortex4, coords, lod).rgb);

                pdf[getBinFromLuminance(luminance)] += 1;
            }
        }
        return pdf;
    }

    float calculateAverageLuminanceFromHistogram(int[HISTOGRAM_BINS] pdf) {
        int density               = 0;
        int closestBinToMedian    = 0;
        float closestDistToMedian = 0.0;

        for(int i = 0; i < HISTOGRAM_BINS; i++) {
            density   += pdf[i];
            float dist = distance(0.5, density);

            if(dist < closestDistToMedian) {
                closestBinToMedian  = i;
                closestDistToMedian = dist;
            }
        }

        return exp((float(closestBinToMedian) - histogram_log_zero) / histogram_log_scale);
    }

    void main() {
        #if EXPOSURE == 1
            float currLuma = pow2(textureLod(colortex4, vec2(0.5), ceil(log2(maxOf(viewSize)))).a);

            float prevLuma = texelFetch(colortex8, ivec2(0), 0).a;
                  prevLuma = prevLuma > 0.0 ? prevLuma : currLuma;
                  prevLuma = isnan(prevLuma) || isinf(prevLuma) ? currLuma : prevLuma;

            float exposureTime = currLuma < prevLuma ? EXPOSURE_GROWTH : EXPOSURE_DECAY;
            avgLuminance = mix(currLuma, prevLuma, exp(-exposureTime * frameTime));
        #endif

        gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
        texCoords   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    }

#elif defined STAGE_FRAGMENT

    /* RENDERTARGETS: 4,8 */

    layout (location = 0) out vec4 color;
    layout (location = 1) out vec4 history;

    #if TAA == 1
        #include "/include/post/taa.glsl"
    #endif

    in float avgLuminance;

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
        #endif

        color.a    = clamp(color.a, minExposure, maxExposure);
        color.rgb *= color.a;
    }
#endif
