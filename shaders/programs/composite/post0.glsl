/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#if DEBUG_HISTOGRAM == 0
    /* RENDERTARGETS: 4,3 */

    layout (location = 0) out vec4 color;
    layout (location = 1) out vec3 bloomBuffer;
#else
    /* RENDERTARGETS: 4,3,6 */

    layout (location = 0) out vec4 color;
    layout (location = 1) out vec3 bloomBuffer;
    layout (location = 2) out vec3 histogram;
#endif

#if BLOOM == 1
    #include "/include/post/bloom.glsl"
#endif

#if DOF == 1
    // https://en.wikipedia.org/wiki/Circle_of_confusion#Determining_a_circle_of_confusion_diameter_from_the_object_field
    float getCoC(float fragDepth, float cursorDepth) {
        return fragDepth < MC_HAND_DEPTH ? 0.0 : abs((FOCAL / APERTURE) * ((FOCAL * (cursorDepth - fragDepth)) / (fragDepth * (cursorDepth - FOCAL)))) * 0.5;
    }

    void depthOfField(inout vec3 color, sampler2D tex, vec2 coords, int quality, float radius, float coc) {
        vec3 dof   = vec3(0.0);
        vec2 noise = vec2(randF(), randF());

        float distFromCenter = pow2(distance(coords, vec2(0.5)));
        vec2  caOffset       = vec2(distFromCenter) * coc / pow2(quality);

        for(int x = 0; x < quality; x++) {
            for(int y = 0; y < quality; y++) {
                vec2 offset = ((vec2(x, y) + noise) - quality * 0.5) * rcp(quality);
            
                if(length(offset) < 0.5) {
                    vec2 sampleCoords = coords + (offset * radius * coc * pixelSize);

                    dof += vec3(
                        texture(tex, sampleCoords + caOffset).r,
                        texture(tex, sampleCoords).g,
                        texture(tex, sampleCoords - caOffset).b
                    );
                }
            }
        }
        color = dof * rcp(pow2(quality));
    }
#endif

#if EXPOSURE == 2

    /*
        SOURCE:
        Alex Tardif - https://www.alextardif.com/HistogramLuminance.html
    */

    const int tiles = 64;
    ivec2 gridSize  = ivec2(viewSize / tiles);
    vec2 tileSize   = 1.0 / gridSize;

    int getBinFromLuminance(float luminance) {
	    return luminance < EPS ? 0 : int(clamp((log2(luminance) * rcpLuminanceRange - (minLuminance * rcpLuminanceRange)) * HISTOGRAM_BINS, 0, HISTOGRAM_BINS - 1));
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

    #if DEBUG_HISTOGRAM == 1
        void drawHistogram(inout vec3 color, float[HISTOGRAM_BINS] pdf, int closestBinToMedian) {
	        vec2 coords = gl_FragCoord.xy * rcp(debugHistogramSize);

	        if(all(lessThan(gl_FragCoord.xy, debugHistogramSize))) {
		        int index = int(HISTOGRAM_BINS * coords.x);
                color     = pdf[index] > coords.y ? vec3(1.0, 0.0, 0.0) * max0(1.0 - abs((index - closestBinToMedian))) : vec3(1.0);
	        }
        }
    #endif
#endif

void main() {
    color = texture(colortex4, texCoords);
    
    #if DOF == 1
        float depth0 = texelFetch(depthtex0, ivec2(gl_FragCoord.xy), 0).r;
        float coc    = getCoC(linearizeDepthFast(depth0), linearizeDepthFast(centerDepthSmooth));

        depthOfField(color.rgb, colortex4, texCoords, 8, DOF_RADIUS, coc);
    #endif

    #if BLOOM == 1
        writeBloom(bloomBuffer);
    #endif

    #if EXPOSURE == 1
        color.a = sqrt(luminance(color.rgb));
    #elif EXPOSURE == 2
        float[HISTOGRAM_BINS] pdf = buildLuminanceHistogram();
        int closestBinToMedian    = getClosestBinToMedian(pdf);

        #if DEBUG_HISTOGRAM == 1
            drawHistogram(histogram, pdf, closestBinToMedian);
        #endif

        color.a = closestBinToMedian * rcpMaxVal8;
    #endif
}
