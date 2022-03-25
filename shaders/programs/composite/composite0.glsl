/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* RENDERTARGETS: 5 */

layout (location = 0) out vec4 color;

#include "/include/fragment/atrous.glsl"

void main() {
    color = texture(colortex5, texCoords);

    #if GI == 1 && GI_FILTER == 1
        aTrousFilter(color.rgb, colortex5, texCoords, 1);
    #endif

    vec4 overlay = texelFetch(colortex2, ivec2(gl_FragCoord.xy), 0);

    // Overlay
    #if TONEMAP == 0
        overlay.rgb = sRGBToAP1Albedo(overlay.rgb);
    #else
        overlay.rgb = sRGBToLinear(overlay.rgb);
    #endif

    color.rgb = mix(color.rgb, overlay.rgb, overlay.a);
}
