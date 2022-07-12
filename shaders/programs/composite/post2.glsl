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

    void purkinje(inout vec3 color) {
        #if TONEMAP == 0
            mat3 toXYZ = sRGB_2_XYZ_MAT, fromXYZ = XYZ_2_sRGB_MAT;
        #else
            rodResponse *= sRGB_2_AP1_ALBEDO;
            mat3 toXYZ   = AP1_2_XYZ_MAT, fromXYZ = XYZ_2_AP1_MAT;
        #endif
        vec3 xyzColor = color * toXYZ;

        vec3 scotopicLum = xyzColor * (1.33 * (1.0 + (xyzColor.y + xyzColor.z) / xyzColor.x) - 1.68);
        float purkinje   = dot(rodResponse, scotopicLum * fromXYZ);

        color = mix(color, purkinje * vec3(0.56, 0.67, 1.0), exp2(-purkinje * 20.0));
    }
#endif


#if CHROMATIC_ABERRATION == 1
    void chromaticAberration(inout vec3 color) {
        #if DOF == 0
            vec2 offset = (1.0 - pow2(texCoords - vec2(0.5))) * ABERRATION_STRENGTH * pixelSize;

            color = vec3(
                texture(colortex4, texCoords + offset).r,
                texture(colortex4, texCoords).g,
                texture(colortex4, texCoords - offset).b
            );
        #endif
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
            #if ACCUMULATION_VELOCITY_WEIGHT == 0
                color *= 1.8;
            #endif
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
    const int lutCount     = 19;
    const int lutTile      = 8;
    const int lutSize      = lutTile * lutTile;
    const int lutRes       = lutSize * lutTile;
    const float invLutTile = 1.0 / lutTile;

    // LUT grid concept from Raspberry shaders (https://rutherin.netlify.app/)
    const vec2 invRes = 1.0 / vec2(lutRes, lutRes * lutCount);
    const mat2 lutGrid = mat2(
        vec2(1.0, invRes.y * lutRes),
        vec2(0.0, (LUT - 1) * invRes.y * lutRes)
    );

    // https://developer.nvidia.com/gpugems/gpugems2/part-iii-high-quality-rendering/chapter-24-using-lookup-tables-accelerate-color
    void applyLUT(sampler2D lookupTable, inout vec3 color) {
        color.b *= lutSize - 1.0;
        int bL   = int(color.b);
        int bH   = bL + 1;

        vec2 offLo = vec2(mod(bL, lutTile), bL / lutTile) * invLutTile;
        vec2 offHi = vec2(mod(bH, lutTile), bH / lutTile) * invLutTile;

        color = mix(
            textureBicubic(lookupTable, (offLo + color.rg * invLutTile) * lutGrid[0] + lutGrid[1]).rgb,
            textureBicubic(lookupTable, (offHi + color.rg * invLutTile) * lutGrid[0] + lutGrid[1]).rgb,
            color.b - bL
        );
    }
#endif

void main() {
    color          = texture(colortex4, texCoords).rgb;
    float exposure = texture(colortex8, texCoords).a;

    #if CHROMATIC_ABERRATION == 1
        chromaticAberration(color);
    #endif

    #if BLOOM == 1
        // https://google.github.io/filament/Filament.md.html#imagingpipeline/physicallybasedcamera/bloom
        float bloomStrgth = max0(exp2(exposure + (BLOOM_STRENGTH + BLOOM_TWEAK) - 3.0));
        color             = mix(color, readBloom(), bloomStrgth);
    #endif

    #if FILM_GRAIN == 1
        color += randF() * color * FILM_GRAIN_STRENGTH;
    #endif

    #if PURKINJE == 1
        purkinje(color);
    #endif
    
    // Tonemapping & Color Correction
    color *= exposure;

    whiteBalance(color);
    vibrance(color,   1.0 + VIBRANCE);
    saturation(color, 1.0 + SATURATION);
    contrast(color,   1.0 + CONTRAST);
    liftGammaGain(color, LIFT * 0.1, 1.0 + GAMMA, 1.0 + GAIN);

    #if TONEMAP >= 0
        tonemap(color);
    #endif

    #if TONEMAP != 0
        color = linearTosRGB(color);
    #endif
    color = clamp01(color);

    #if LUT > 0
        applyLUT(colortex7, color);
    #endif
}
