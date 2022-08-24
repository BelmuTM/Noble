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

const float airIOR  = 1.00029;
const float waterF0 = 0.02;

// Maximum values for X amount of bits (2^x - 1)
const float maxVal8     = 255.0;
const float maxVal16    = 65535.0;
const float rcpMaxVal8  = 0.00392156;
const float rcpMaxVal9  = 0.00195694;
const float rcpMaxVal10 = 0.00097751;
const float rcpMaxVal11 = 0.00048851;
const float rcpMaxVal16 = 0.00001525;

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
