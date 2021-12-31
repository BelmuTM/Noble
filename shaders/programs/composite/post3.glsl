/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* DRAWBUFFERS:0 */

layout (location = 0) out vec4 color;

#if SHARPEN == 1
    /*
        SOURCES / CREDITS:

        spolsh:   https://www.shadertoy.com/view/XlSBRW
        SixSeven: https://www.curseforge.com/minecraft/customization/voyager-shader-2-0
    */

    void sharpeningFilter(inout vec3 color) {
        float avgLuma = 0.0, weight = 0.0;

        for(int x = -1; x <= 1; x++) {
            for(int y = -1; y <= 1; y++) {
                avgLuma += luminance(texture(colortex0, texCoords + vec2(x, y) * pixelSize).rgb);
                weight++;
            }
        }
        avgLuma /= weight;

        float centerLuma = luminance(color);
        color *= (centerLuma + (centerLuma - avgLuma) * SHARPEN_STRENGTH) / centerLuma;
    }
#endif

void main() {
    color = texture(colortex0, texCoords);

    #if SHARPEN == 1
        sharpeningFilter(color.rgb);
    #endif
}
