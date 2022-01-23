/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* DRAWBUFFERS:04 */

layout (location = 0) out vec4 color;
layout (location = 1) out vec4 bloomBuffer;

#include "/include/utility/blur.glsl"
#include "/include/post/bloom.glsl"
#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/shadows.glsl"
#include "/include/atmospherics/fog.glsl"

void main() {
    color = texture(colortex0, texCoords);

    #if BLOOM == 1
        bloomBuffer.rgb = writeBloom();
    #endif

    #if VL == 1
        #if VL_FILTER == 1
            color.rgb += gaussianBlur(texCoords, colortex7, 1.5, 2.0, 4).rgb;
        #else
            color.rgb += texture(colortex7, texCoords).rgb;
        #endif
    #else
        #if RAIN_FOG == 1
            if(rainStrength > 0.0 && isEyeInWater < 0.5) {
                vec3 viewPos = getViewPos0(texCoords);
                vlGroundFog(color.rgb, viewPos);
            }
        #endif
    #endif
}
