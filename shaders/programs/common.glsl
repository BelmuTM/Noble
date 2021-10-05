#include "/lib/uniforms.glsl"
vec3 blueNoise = texelFetch(noisetex, ivec2(mod(gl_FragCoord, noiseRes)), 0).rgb;
vec3 animBlueNoise = texelFetch(noisetex, (ivec2(gl_FragCoord) + ivec2(frameCounter % 100) * ivec2(113, 127)) & ivec2(511), 0).rgb;

#include "/lib/noise/bayer.glsl"
#include "/lib/noise/noise.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/util/utils.glsl"
#include "/lib/util/color.glsl"
