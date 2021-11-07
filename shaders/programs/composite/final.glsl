/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/settings.glsl"
#include "/programs/common.glsl"
#include "/lib/util/blur.glsl"

#include "/lib/post/bloom.glsl"
#include "/lib/post/exposure.glsl"

#if UNDERWATER_DISTORTION == 1
    vec2 underwaterDistortionCoords(vec2 coords) {
        const float scale = 25.0;
        float speed = frameTimeCounter * WATER_DISTORTION_SPEED;
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
        vec3 xyzColor = linearToXYZ(color);

        vec3 scotopicLuma = xyzColor * (1.33 * (1.0 + (xyzColor.y + xyzColor.z) / xyzColor.x) - 1.68);
        float purkinje = dot(rodResponse, XYZtoLinear(scotopicLuma));

        return mix(color, purkinje * vec3(0.5, 0.7, 1.0), exp2(-purkinje * 100.0));
    }
#endif


#if CHROMATIC_ABERRATION == 1
    vec3 computeAberration(vec3 color) {
        vec2 offset;
        #if DOF == 0
            vec2 dist = texCoords - vec2(0.5);
            offset = (1.0 - (dist * dist)) * ABERRATION_STRENGTH * pixelSize;
        #else
            float depth = linearizeDepth(texture(depthtex0, texCoords).r);
            float coc = getCoC(depth, linearizeDepth(centerDepthSmooth));
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
    #if TONEMAPPING == 0
        color = whitePreservingReinhard(color); // Reinhard
    #elif TONEMAPPING == 1
        color = uncharted2(color); // Uncharted 2
    #elif TONEMAPPING == 2
        color = burgess(color); // Burgess
    #elif TONEMAPPING == 3
        color = ACESFitted(color); // ACES
    #endif
}

#if LUT == 1
    const int lutRes        = 512;
    const int sqrTileSize   = int(pow(lutRes, 2.0 / 3.0));
    const int tileSize      = int(sqrt(sqrTileSize));
    const float invTileSize = 1.0 / tileSize;

    const float minColLUT = 0.025;
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
    
    vec4 Result = texture(colortex0, tempCoords);
    float exposure = max(0.0, computeExposure(texture(colortex3, texCoords).a));

    #if CHROMATIC_ABERRATION == 1
        Result.rgb = computeAberration(Result.rgb);
    #endif

    #if BLOOM == 1
        // I wasn't supposed to use magic numbers like this in Noble :Sadge:
        Result.rgb += clamp01(readBloom().rgb * 0.009 * clamp01(BLOOM_STRENGTH + clamp(rainStrength, 0.0, 0.5)));
    #endif

    #if PURKINJE == 1
        Result.rgb = purkinje(Result.rgb);
    #endif

    #if LUT == 1
        applyLUT(colortex10, Result.rgb);
    #endif
    
    // Tonemapping & Color Correction
    Result.rgb *= exposure;
    tonemap(Result.rgb);
    Result.rgb = vibranceSaturation(Result.rgb, VIBRANCE, SATURATION);
    Result.rgb = contrast(Result.rgb, CONTRAST) + BRIGHTNESS;

    // Vignette
    #if VIGNETTE == 1
        vec2 coords = texCoords * (1.0 - texCoords.yx);
        finalCol *= pow(coords.x * coords.y * 15.0, VIGNETTE_STRENGTH);
    #endif

    Result = linearToSRGB(Result);
    Result.rgb += bayer64(gl_FragCoord.xy) / 255.0;

    /*DRAWBUFFERS:0*/
    gl_FragData[0] = Result;
}
