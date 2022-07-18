/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/*
    const bool colortex4MipmapEnabled = true;
*/

#include "/settings.glsl"
#include "/include/uniforms.glsl"

#include "/include/utility/rng.glsl"
#include "/include/utility/math.glsl"
#include "/include/utility/transforms.glsl"
#include "/include/utility/color.glsl"
#include "/include/utility/phase.glsl"

#include "/include/post/aces/lib/transforms.glsl"

#include "/include/atmospherics/constants.glsl"

#include "/include/material.glsl"

bool isSky(vec2 coords)  { return texture(depthtex0, coords).r == 1.0;                          }
bool isHand(vec2 coords) { return linearizeDepth(texture(depthtex0, coords).r) < MC_HAND_DEPTH; }

float getNormalWeight(vec3 normal0, vec3 normal1, float sigma) {
    return pow(max0(dot(normal0, normal1)), sigma);
}

float getDepthWeight(float depth0, float depth1, float sigma) {
    return exp(-abs(linearizeDepth(depth0) - linearizeDepth(depth1)) * sigma);
}
