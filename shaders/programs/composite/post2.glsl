/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* RENDERTARGETS: 4 */

layout (location = 0) out vec3 color;

#include "/include/post/bloom.glsl"

// Rod response coefficients & blending method provided by Jessie#7257
// SOURCE: http://www.diva-portal.org/smash/get/diva2:24136/FULLTEXT01.pdf
#if PURKINJE == 1
    vec3 rodResponse = vec3(7.15e-5, 4.81e-1, 3.28e-1);

    void purkinje(inout vec3 color, float exposure) {
        color /= exposure;

        #if TONEMAP == 0
            mat3 toXYZ = SRGB_2_XYZ_MAT, fromXYZ = XYZ_2_SRGB_MAT;
        #else
            rodResponse *= SRGB_2_AP1_ALBEDO;
            mat3 toXYZ   = AP1_2_XYZ_MAT, fromXYZ = XYZ_2_AP1_MAT;
        #endif
        vec3 xyzColor = color * toXYZ;

        vec3 scotopicLum = xyzColor * (1.33 * (1.0 + (xyzColor.y + xyzColor.z) / xyzColor.x) - 1.68);
        float purkinje   = dot(rodResponse, scotopicLum * fromXYZ);

        color = mix(color, purkinje * vec3(0.56, 0.67, 1.0), exp2(-purkinje * 20.0)) * exposure;
    }
#endif

#if TONEMAP == 0
    #include "/include/post/aces/lib/splines.glsl"

    #include "/include/post/aces/rrt.glsl"
    #include "/include/post/aces/odt.glsl"
#endif

#if TONEMAP >= 0
    void tonemap(inout vec3 color) {
        #if TONEMAP == 0
            color *= AP1_2_AP0_MAT;
            color *= 1.5;

            rrt(color);
            odt(color);                          // ACES
        #elif TONEMAP == 1
            burgess(color);                      // Burgess
        #elif TONEMAP == 2
            whitePreservingReinhard(color, 2.0); // Reinhard
        #elif TONEMAP == 3
            lottes(color);                       // Lottes
        #elif TONEMAP == 4
            uchimura(color);                     // Uchimura
        #elif TONEMAP == 5
            uncharted2(color);                   // Uncharted 2
        #endif
    }
#endif

#if LUT > 0
    const int lutTileSize = 8;
    const int lutSize     = lutTileSize  * lutTileSize;
    const vec2 lutRes     = vec2(lutSize * lutTileSize);

    const float rcpLutTileSize = 1.0 / lutTileSize;
    const vec2  rcpLutTexSize  = 1.0 / lutRes;

    // https://developer.nvidia.com/gpugems/gpugems2/part-iii-high-quality-rendering/chapter-24-using-lookup-tables-accelerate-color
    void applyLUT(sampler2D lookupTable, inout vec3 color) {
        color = min(color, vec3(0.985));

        #if DEBUG_LUT == 1
            if(gl_FragCoord.x < 256.0 && gl_FragCoord.y < 256.0) {
                color = texture(lookupTable, gl_FragCoord.xy * rcpLutTexSize * 2.0).rgb;
                return;
            }
        #endif

        color.b *= (lutSize - 1.0);
        int bL   = int(color.b);
        int bH   = bL + 1;

        vec2 offLo = vec2(bL % lutTileSize, bL / lutTileSize) * rcpLutTileSize;
        vec2 offHi = vec2(bH % lutTileSize, bH / lutTileSize) * rcpLutTileSize;

        color = mix(
            textureLodLinearRGB(lookupTable, offLo + color.rg * rcpLutTileSize, lutRes, 0).rgb,
            textureLodLinearRGB(lookupTable, offHi + color.rg * rcpLutTileSize, lutRes, 0).rgb,
            color.b - bL
        );
    }
#endif

void main() {
    vec4 tmp = texture(colortex4, texCoords);
    color    = tmp.rgb;

    #if BLOOM == 1
        // https://google.github.io/filament/Filament.md.html#imagingpipeline/physicallybasedcamera/bloom
        float bloomStrgth = max0(exp2(tmp.a + (BLOOM_STRENGTH - 1.0) - 3.0));
        color             = mix(color / tmp.a, readBloom(), bloomStrgth) * tmp.a;
    #endif

    #if FILM_GRAIN == 1
        color += randF() * color * FILM_GRAIN_STRENGTH;
    #endif

    #if PURKINJE == 1
        purkinje(color, tmp.a);
    #endif
    
    // Tonemapping & Color Correction
    whiteBalance(color);
    vibrance(color,   1.0 + VIBRANCE);
    saturation(color, 1.0 + SATURATION);
    contrast(color,   1.0 + CONTRAST);
    liftGammaGain(color, LIFT * 0.1, 1.0 + GAMMA, 1.0 + GAIN);

    #if TONEMAP >= 0
        tonemap(color);
    #endif

    #if TONEMAP != 0
        color = linearToSrgb(color);
    #endif
    color = clamp01(color);

    #if LUT > 0
        applyLUT(colortex7, color);
    #endif

    #if DEBUG_HISTOGRAM == 1 && EXPOSURE == 2
	    if(all(lessThan(gl_FragCoord.xy, debugHistogramSize))) {
            color = texture(colortex6, texCoords).rgb;
        }
    #endif
}
