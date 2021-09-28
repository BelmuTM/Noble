#include "/lib/uniforms.glsl"
vec3 blueNoise = texelFetch(noisetex, ivec2(mod(gl_FragCoord, noiseRes)), 0).rgb;

#include "/lib/noise/bayer.glsl"
#include "/lib/noise/noise.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/util/utils.glsl"
#include "/lib/util/color.glsl"
