/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* RENDERTARGETS: 0 */

layout (location = 0) out vec3 color;

#include "/include/fragment/atrous.glsl"

void main() {
    #if GI == 0
        color = texture(colortex0, texCoords * GI_RESOLUTION).rgb;
    #else
        #if GI_FILTER == 0
            color = texture(colortex0, texCoords * GI_RESOLUTION).rgb;
        #else
            aTrousFilter(color, colortex0, texCoords * GI_RESOLUTION, 0);
        #endif
    #endif

    // Overlay
    vec4 overlay = texelFetch(colortex4, ivec2(gl_FragCoord.xy), 0);
    color        = mix(color, sRGBToLinear(overlay.rgb) * (sunAngle <= 0.5 ? sunIlluminance : moonIlluminance), overlay.a);
}
