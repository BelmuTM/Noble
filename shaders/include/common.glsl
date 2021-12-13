/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/include/uniforms.glsl"

vec3 blueNoise = texelFetch(noisetex, ivec2(mod(gl_FragCoord, noiseRes)), 0).rgb;

#include "/include/utility/bayer.glsl"
#include "/include/utility/noise.glsl"
#include "/include/utility/math.glsl"
#include "/include/utility/transforms.glsl"

float getSkyLightmap(vec2 coords) {
    float lightmap = clamp01(texture(colortex1, coords).w);
    return smoothstep(0.90, 0.96, lightmap); // Concept from Eldeston#3590
}

bool isSky(vec2 coords) {
    return texture(depthtex0, coords).r == 1.0;
}

bool isHand(float depth) {
    return linearizeDepth(depth) < 0.56;
}

#include "/include/utility/color.glsl"
#include "/include/atmospherics/constants.glsl"
