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

out vec3 colorOut;

in vec2 textureCoords;

#include "/settings.glsl"
#include "/include/taau_scale.glsl"

#include "/include/common.glsl"

#include "/include/utility/rng.glsl"

#if UNDERWATER_DISTORTION == 1

    void underwaterDistortion(inout vec2 coords) {
        float speed   = frameTimeCounter * WATER_DISTORTION_SPEED;
        float offsetX = coords.x * 25.0 + speed;
        float offsetY = coords.y * 25.0 + speed;

        vec2 distortion = coords + vec2(
            WATER_DISTORTION_AMPLITUDE * cos(offsetX + offsetY) * 0.01 * cos(offsetY),
            WATER_DISTORTION_AMPLITUDE * sin(offsetX - offsetY) * 0.01 * sin(offsetY)
        );

        if (saturate(distortion) == distortion) {
            coords = distortion;
        }
    }
    
#endif

#if LUT > 0

    #include "/include/utility/sampling.glsl"

    const int lutTileSize = 8;
    const int lutSize     = lutTileSize  * lutTileSize;
    const vec2 lutRes     = vec2(lutSize * lutTileSize);

    const float rcpLutTileSize = 1.0 / lutTileSize;
    const vec2  rcpLutTexSize  = 1.0 / lutRes;

    // https://developer.nvidia.com/gpugems/gpugems2/part-iii-high-quality-rendering/chapter-24-using-lookup-tables-accelerate-color
    void applyLUT(inout vec3 color) {
        color = clamp(color, vec3(0.02745098039), vec3(0.96862745098));

        #if DEBUG_LUT == 1
            if (all(lessThan(gl_FragCoord.xy, ivec2(256)))) {
                color = texture(LUT_BUFFER, gl_FragCoord.xy * rcpLutTexSize * 2.0).rgb;
                return;
            }
        #endif

        color.b *= (lutSize - 1.0);
        int bL   = int(color.b);
        int bH   = bL + 1;

        vec2 offLo = vec2(bL % lutTileSize, bL / lutTileSize) * rcpLutTileSize;
        vec2 offHi = vec2(bH % lutTileSize, bH / lutTileSize) * rcpLutTileSize;

        color = mix(
            textureLodLinearRGB(LUT_BUFFER, offLo + color.rg * rcpLutTileSize, lutRes, 0).rgb,
            textureLodLinearRGB(LUT_BUFFER, offHi + color.rg * rcpLutTileSize, lutRes, 0).rgb,
            color.b - bL
        );
    }

#endif

#if SHARPEN == 1

    /*
        SOURCES / CREDITS:
        spolsh: https://www.shadertoy.com/view/XlSBRW
    */

    void sharpeningFilter(inout vec3 color, vec2 coords) {
        float avgLuma = 0.0, weight = 0.0;

        for (int x = -1; x <= 1; x++) {
            for (int y = -1; y <= 1; y++, weight++) {
                avgLuma += luminance(texture(MAIN_BUFFER, coords + vec2(x, y) * texelSize).rgb);
            }
        }
        avgLuma /= weight;

        float centerLuma = luminance(color);
        color *= (centerLuma + (centerLuma - avgLuma) * SHARPEN_STRENGTH) / centerLuma;
    }
    
#endif

#if PALETTE > 0
    #include "/include/post/palette.glsl"
#endif

#if EIGHT_BITS_FILTER == 1

    void quantizeColor(inout vec3 color, float quantizationPeriod) {
        color = floor((color + quantizationPeriod * 0.5) / quantizationPeriod) * quantizationPeriod;
    }

    void ditherColor(inout vec3 color, float quantizationPeriod) {
        color += (bayer2(gl_FragCoord.xy) - 0.5) * quantizationPeriod;
    }

    vec4 samplePixelatedBuffer(sampler2D tex, vec2 coords, int size) {
        vec2 aspectCorrectedSize = size * vec2(aspectRatio, 1.0);
        return texelFetch(tex, ivec2((floor(coords * aspectCorrectedSize) / aspectCorrectedSize) * viewSize), 0);
    }

#endif

#if CEL_SHADING == 1

    void celShading(inout vec3 color) {
        float luminance = luminance(color);
	          color    /= luminance / (floor(luminance * CEL_SHADES) / CEL_SHADES);
    }

#endif

void main() {
    vec2 distortCoords = textureCoords;

    #if UNDERWATER_DISTORTION == 1
        if (isEyeInWater == 1) underwaterDistortion(distortCoords);
    #endif

    #if EIGHT_BITS_FILTER == 0
        colorOut = texture(MAIN_BUFFER, distortCoords).rgb;
    #else
        colorOut = samplePixelatedBuffer(MAIN_BUFFER, distortCoords, 300).rgb;
    #endif

    #if SHARPEN == 1
        sharpeningFilter(colorOut, distortCoords);
    #endif

    #if LUT > 0
        applyLUT(colorOut);
    #endif

    #if FILM_GRAIN == 1
        colorOut += randF() * colorOut * FILM_GRAIN_STRENGTH;
    #endif

    #if VIGNETTE == 1
        vec2 coords = textureCoords * (1.0 - textureCoords.yx);
        colorOut   *= pow(coords.x * coords.y * 15.0, VIGNETTE_STRENGTH);
    #endif

    #if CEL_SHADING == 1
        celShading(colorOut);
    #endif

    #if PALETTE > 0
        applyColorPalette(colorOut);
    #endif

    #if EIGHT_BITS_FILTER == 1
        const int   colorPaletteSize   = 2;
        const float quantizationPeriod = 1.0 / colorPaletteSize;

        ditherColor  (colorOut, quantizationPeriod);
        quantizeColor(colorOut, quantizationPeriod);
    #else
        #if CEL_SHADING == 0
            colorOut += bayer8(gl_FragCoord.xy) * rcpMaxFloat8;
        #endif
    #endif
}
