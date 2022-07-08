/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

out vec3 color;

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

#if SHARPEN == 1
    /*
        SOURCES / CREDITS:
        spolsh:   https://www.shadertoy.com/view/XlSBRW
        SixSeven: https://www.curseforge.com/minecraft/customization/voyager-shader-2-0
    */

    void sharpeningFilter(inout vec3 color, vec2 coords) {
        float avgLuma = 0.0, weight = 0.0;

        for(int x = -1; x <= 1; x++) {
            for(int y = -1; y <= 1; y++) {
                avgLuma += luminance(texture(colortex4, coords + vec2(x, y) * pixelSize).rgb);
                weight++;
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

    color = texture(colortex4, distortCoords).rgb;

    #if SHARPEN == 1
        sharpeningFilter(color, distortCoords);
    #endif

    #if VIGNETTE == 1
        vec2 coords = texCoords * (1.0 - texCoords.yx);
        color      *= pow(coords.x * coords.y * 15.0, VIGNETTE_STRENGTH);
    #endif

    color += bayer64(gl_FragCoord.xy) / maxVal8;
}
