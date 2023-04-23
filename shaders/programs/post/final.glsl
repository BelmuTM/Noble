/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

out vec3 color;

#include "/include/common.glsl"

#if UNDERWATER_DISTORTION == 1
    void underwaterDistortion(inout vec2 coords) {
        float speed   = frameTimeCounter * WATER_DISTORTION_SPEED;
        float offsetX = coords.x * 25.0 + speed;
        float offsetY = coords.y * 25.0 + speed;

        vec2 distorted = coords + vec2(
            WATER_DISTORTION_AMPLITUDE * cos(offsetX + offsetY) * 0.01 * cos(offsetY),
            WATER_DISTORTION_AMPLITUDE * sin(offsetX - offsetY) * 0.01 * sin(offsetY)
        );
        coords = saturate(distorted) != distorted ? coords : distorted;
    }
#endif

#if LUT > 0
    const int lutTileSize = 8;
    const int lutSize     = lutTileSize  * lutTileSize;
    const vec2 lutRes     = vec2(lutSize * lutTileSize);

    const float rcpLutTileSize = 1.0 / lutTileSize;
    const vec2  rcpLutTexSize  = 1.0 / lutRes;

    #include "/include/utility/sampling.glsl"

    // https://developer.nvidia.com/gpugems/gpugems2/part-iii-high-quality-rendering/chapter-24-using-lookup-tables-accelerate-color
    void applyLUT(sampler2D lookupTable, inout vec3 color) {
        color = clamp(color, vec3(0.0), vec3(0.985));

        #if DEBUG_LUT == 1
            if(all(lessThan(gl_FragCoord.xy, ivec2(256)))) {
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

#if SHARPEN == 1
    /*
        SOURCES / CREDITS:
        spolsh: https://www.shadertoy.com/view/XlSBRW
    */

    void sharpeningFilter(inout vec3 color, vec2 coords) {
        float avgLuma = 0.0, weight = 0.0;

        for(int x = -1; x <= 1; x++) {
            for(int y = -1; y <= 1; y++, weight++) {
                avgLuma += luminance(texture(MAIN_BUFFER, coords + vec2(x, y) * pixelSize).rgb);
            }
        }
        avgLuma /= weight;

        float centerLuma = luminance(color);
        color *= (centerLuma + (centerLuma - avgLuma) * SHARPEN_STRENGTH) / centerLuma;
    }
#endif

void main() {
    vec2 distortCoords = texCoords;

    #if UNDERWATER_DISTORTION == 1
        if(isEyeInWater == 1) underwaterDistortion(distortCoords);
    #endif

    color = texture(MAIN_BUFFER, distortCoords).rgb;

    #if SHARPEN == 1
        sharpeningFilter(color, distortCoords);
    #endif

    #if LUT > 0
        applyLUT(LUT_BUFFER, color);
    #endif

    #if FILM_GRAIN == 1
        color += randF() * color * FILM_GRAIN_STRENGTH;
    #endif

    #if VIGNETTE == 1
        vec2 coords = texCoords * (1.0 - texCoords.yx);
        color      *= pow(coords.x * coords.y * 15.0, VIGNETTE_STRENGTH);
    #endif

    color += bayer8(gl_FragCoord.xy) * rcpMaxVal8;
}
