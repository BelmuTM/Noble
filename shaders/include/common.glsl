/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/settings.glsl"
#include "/include/uniforms.glsl"

#include "/include/utility/bayer.glsl"
#include "/include/utility/noise.glsl"
#include "/include/utility/math.glsl"
#include "/include/utility/transforms.glsl"
#include "/include/utility/color.glsl"

#include "/include/atmospherics/constants.glsl"
#include "/include/atmospherics/phase.glsl"

#include "/include/material.glsl"

bool isSky(vec2 coords) {
    return texture(depthtex0, coords).r == 1.0;
}

bool isHand(float depth) {
    return linearizeDepth(depth) < 0.56;
}
