/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/settings.glsl"
#include "/include/common.glsl"
#include "/include/utility/blur.glsl"

#include "/include/post/bloom.glsl"
#include "/include/post/exposure.glsl"

#if UNDERWATER_DISTORTION == 1
    vec2 underwaterDistortionCoords(vec2 coords) {
        const float scale = 25.0;
        float speed   = frameTimeCounter * WATER_DISTORTION_SPEED;
        float offsetX = coords.x * scale + speed;
        float offsetY = coords.y * scale + speed;

        vec2 distorted = coords + vec2(
            WATER_DISTORTION_AMPLITUDE * cos(offsetX + offsetY) * 0.01 * cos(offsetY),
            WATER_DISTORTION_AMPLITUDE * sin(offsetX - offsetY) * 0.01 * sin(offsetY)
        );

        return clamp01(distorted) != distorted ? coords : distorted;
    }
#endif

// Rod response coefficients & blending method provided by Jessie#7257
// SOURCE: http://www.diva-portal.org/smash/get/diva2:24136/FULLTEXT01.pdf
#if PURKINJE == 1
    vec3 purkinje(vec3 color) {
        vec3 rodResponse = vec3(7.15e-5, 4.81e-1, 3.28e-1);
        vec3 xyzColor    = linearToXYZ(color);

        vec3 scotopicLuma = xyzColor * (1.33 * (1.0 + (xyzColor.y + xyzColor.z) / xyzColor.x) - 1.68);
        float purkinje    = dot(rodResponse, XYZtoLinear(scotopicLuma));

        return mix(color, purkinje * vec3(0.5, 0.7, 1.0), exp2(-purkinje * 20.0));
    }
#endif


#if CHROMATIC_ABERRATION == 1
    vec3 chromaticAberration(vec3 color) {
        vec2 offset;
        #if DOF == 0
            vec2 dist = texCoords - vec2(0.5);
            offset = (1.0 - (dist * dist)) * ABERRATION_STRENGTH * pixelSize;
        #else
            float coc = texture(colortex5, texCoords).a;
            offset = coc * ABERRATION_STRENGTH * pixelSize;
        #endif

        return vec3(
            texture(colortex0, texCoords + offset).r,
            texture(colortex0, texCoords).g,
            texture(colortex0, texCoords - offset).b
        );
    }
#endif

void tonemap(inout vec3 color) {
    #if TONEMAP == 0
        color = whitePreservingReinhard(color, 15.0); // Reinhard
    #elif TONEMAP == 1
        color = uncharted2(color); // Uncharted 2
    #elif TONEMAP == 2
        color = burgess(color); // Burgess
    #elif TONEMAP == 3
        color = ACESFitted(color); // ACES
    #endif
}

#if LUT == 1
    const int lutRes        = 512;
    const int sqrTileSize   = 64;
    const int tileSize      = 8;
    const float invTileSize = 1.0 / tileSize;

    const float minColLUT = 0.03;
    // https://developer.nvidia.com/gpugems/gpugems2/part-iii-high-quality-rendering/chapter-24-using-lookup-tables-accelerate-color
    void applyLUT(sampler2D lut, inout vec3 color) {
        color = clamp(color, vec3(minColLUT), vec3(255.0 / 256.0));

        int b0 = int(floor(color.b * sqrTileSize));
        int b1 = int( ceil(color.b * sqrTileSize));

        vec2 off0 = vec2(mod(b0, tileSize), b0 / tileSize) * invTileSize;
        vec2 off1 = vec2(mod(b1, tileSize), b1 / tileSize) * invTileSize;

        color = mix(
            texture(lut, off0 + color.rg * invTileSize).rgb,
            texture(lut, off1 + color.rg * invTileSize).rgb,
            fract(color.b * sqrTileSize)
        );
    }
#endif

void main() {
    vec2 tempCoords = texCoords;
    #if UNDERWATER_DISTORTION == 1
        if(isEyeInWater == 1) tempCoords = underwaterDistortionCoords(tempCoords);
    #endif
    vec4 color = texture(colortex0, tempCoords);

    #if CHROMATIC_ABERRATION == 1
        color.rgb = chromaticAberration(color.rgb);
    #endif

    #if BLOOM == 1
        //color.rgb += readBloom().rgb * clamp01(BLOOM_STRENGTH + clamp(rainStrength, 0.0, 0.5));
    #endif

    #if PURKINJE == 1
        color.rgb = purkinje(color.rgb);
    #endif

    #if FILM_GRAIN == 1
        color.rgb += uniformAnimatedNoise(hash22(gl_FragCoord.xy + frameTimeCounter * 5.0)).x * color.rgb * FILM_GRAIN_STRENGTH;
    #endif
    
    // Tonemapping & Color Correction

    color.rgb *= computeExposure(texture(colortex3, texCoords).a);

    tonemap(color.rgb);
    vibrance(color.rgb,   VIBRANCE);
    saturation(color.rgb, SATURATION);
    contrast(color.rgb,   CONTRAST);
    color.rgb +=          BRIGHTNESS;

    // Vignette
    #if VIGNETTE == 1
        vec2 coords = texCoords * (1.0 - texCoords.yx);
        color      *= pow(coords.x * coords.y * 15.0, VIGNETTE_STRENGTH);
    #endif

    color.rgb = clamp01(color.rgb);
    color     = TONEMAP == 2 ? color : linearToSRGB(color);

    #if LUT == 1
        applyLUT(colortex10, color.rgb);
    #endif

    color.rgb += bayer64(gl_FragCoord.xy) / 64.0;

    /*DRAWBUFFERS:0*/
    gl_FragData[0] = color;
}
