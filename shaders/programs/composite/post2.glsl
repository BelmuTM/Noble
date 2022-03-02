/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* RENDERTARGETS: 0 */

layout (location = 0) out vec3 color;

#include "/include/post/bloom.glsl"
#include "/include/post/exposure.glsl"

#if UNDERWATER_DISTORTION == 1
    void underwaterDistortion(inout vec2 coords) {
        const float scale = 25.0;
        float speed   = frameTimeCounter * WATER_DISTORTION_SPEED;
        float offsetX = coords.x * scale + speed;
        float offsetY = coords.y * scale + speed;

        vec2 distorted = coords + vec2(
            WATER_DISTORTION_AMPLITUDE * cos(offsetX + offsetY) * 0.01 * cos(offsetY),
            WATER_DISTORTION_AMPLITUDE * sin(offsetX - offsetY) * 0.01 * sin(offsetY)
        );

        coords = clamp01(distorted) != distorted ? coords : distorted;
    }
#endif

// Rod response coefficients & blending method provided by Jessie#7257
// SOURCE: http://www.diva-portal.org/smash/get/diva2:24136/FULLTEXT01.pdf
#if PURKINJE == 1
    void purkinje(inout vec3 color, float exposure) {
        vec3 rodResponse = vec3(7.15e-5, 4.81e-1, 3.28e-1);
        vec3 xyzColor    = linearToXYZ(color);

        vec3 scotopicLum = xyzColor * (1.33 * (1.0 + (xyzColor.y + xyzColor.z) / xyzColor.x) - 1.68);
        float purkinje   = dot(rodResponse, XYZToLinear(scotopicLum));

        color = max0(mix(color, purkinje * vec3(0.56, 0.67, 1.0), exp2(-purkinje * 30.0 * exposure)));
    }
#endif


#if CHROMATIC_ABERRATION == 1
    void chromaticAberration(inout vec3 color) {
        #if DOF == 0
            vec2 offset = (1.0 - pow2(texCoords - vec2(0.5))) * ABERRATION_STRENGTH * pixelSize;

            color = vec3(
                texture(colortex0, texCoords + offset).r,
                texture(colortex0, texCoords).g,
                texture(colortex0, texCoords - offset).b
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
        color = clamp(color, vec3(0.0), vec3(maxVal8 / 256.0));

        color.b *= lutSize - 1.0;
        int b0 = int(color.b);
        int b1 = b0 + 1;

        vec2 off0 = vec2(mod(b0, lutTile), b0 / lutTile) * invLutTile;
        vec2 off1 = vec2(mod(b1, lutTile), b1 / lutTile) * invLutTile;

        color = mix(
            texture(lookupTable, (off0 + color.rg * invLutTile) * lutGrid[0] + lutGrid[1]).rgb,
            texture(lookupTable, (off1 + color.rg * invLutTile) * lutGrid[0] + lutGrid[1]).rgb,
            fract(color.b)
        );
    }
#endif

void main() {
    vec2 tempCoords = texCoords;
    #if UNDERWATER_DISTORTION == 1
        if(isEyeInWater == 1) underwaterDistortion(tempCoords);
    #endif
    
    color          = texture(colortex0, tempCoords).rgb;
    float exposure = computeExposure(texture(colortex8, texCoords).a);

    #if CHROMATIC_ABERRATION == 1
        chromaticAberration(color);
    #endif

    #if BLOOM == 1
        float bloomStrength = max0(exp2(exposure - 3.0 + (-BLOOM_TWEAK_VAL + BLOOM_STRENGTH)));
        color = mix(color, readBloom(), bloomStrength);
    #endif

    #if FILM_GRAIN == 1
        color += randF() * color * FILM_GRAIN_STRENGTH;
    #endif

    #if PURKINJE == 1
        purkinje(color, exposure);
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

    color = linearTosRGB(color);
    color = clamp01(color);

    #if LUT > 0
        applyLUT(colortex9, color);
    #endif
}
