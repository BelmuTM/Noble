#include "/include/uniforms.glsl"

vec3 blueNoise     = texelFetch(noisetex, ivec2(mod(gl_FragCoord, noiseRes)), 0).rgb;
vec3 animBlueNoise = texelFetch(noisetex, (ivec2(gl_FragCoord + (frameCounter % 100)) * ivec2(113, 127)) & ivec2(511), 0).rgb;

#include "/include/utility/bayer.glsl"
#include "/include/utility/noise.glsl"
#include "/include/utility/math.glsl"
#include "/include/utility/transforms.glsl"

bool isSky(vec2 coords) {
    return texture(depthtex0, coords).r == 1.0;
}

bool isHand(float depth) {
    return linearizeDepth(depth) < 0.56;
}

#include "/include/fragment/lightmap.glsl"
#include "/include/utility/color.glsl"
