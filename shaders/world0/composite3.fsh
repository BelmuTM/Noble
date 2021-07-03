/***********************************************/
/*       Copyright (C) Noble SSRT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#version 400 compatibility

varying vec2 texCoords;

#include "/settings.glsl"
#include "/lib/composite_uniforms.glsl"
#include "/lib/frag/dither.glsl"
#include "/lib/frag/noise.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/util/utils.glsl"
#include "/lib/util/blur.glsl"

void main() {
    vec4 Result = texture2D(colortex0, texCoords);

    #if SSGI == 1
        float Depth = texture2D(depthtex0, texCoords).r;
        if(Depth == 1.0) {
            gl_FragData[0] = Result;
            return;
        }

        float F0 = texture2D(colortex2, texCoords).g;
        bool isMetal = (F0 * 255.0) > 229.5;

        vec3 Albedo = texture2D(colortex5, texCoords).rgb;
        vec4 GlobalIllumination = texture2D(colortex7, texCoords);

        #if SSGI_FILTER == 1
            /* HIGH QUALITY - MORE EXPENSIVE */
            GlobalIllumination = smartDeNoise(colortex7, texCoords, 5.0, 2.0, 0.9);

            /* DECENT QUALITY - LESS EXPENSIVE */
            //GlobalIllumination = bilateralBlur(colortex7);
        #endif

        Result.rgb += isMetal ? vec3(0.0) : GlobalIllumination.rgb;
    #endif

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = Result;
}