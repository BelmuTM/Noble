#include "/include/uniforms.glsl"
vec3 blueNoise = texelFetch(noisetex, ivec2(mod(gl_FragCoord, noiseRes)), 0).rgb;
vec3 animBlueNoise = texelFetch(noisetex, (ivec2(gl_FragCoord + (frameCounter % 100)) * ivec2(113, 127)) & ivec2(511), 0).rgb;

#include "/include/utility/bayer.glsl"
#include "/include/utility/noise.glsl"
#include "/include/utility/math.glsl"
#include "/include/utility/transforms.glsl"

vec3 getViewPos(vec2 coords) {
    vec3 clipPos = vec3(coords, texture(depthtex0, coords).r) * 2.0 - 1.0;
    vec4 tmp = gbufferProjectionInverse * vec4(clipPos, 1.0);
    return tmp.xyz / tmp.w;
}

bool isSky(vec2 coords) {
    return texture(depthtex0, coords).r == 1.0;
}

bool isHand(float depth) {
    return linearizeDepth(depth) < 0.56;
}

#include "/include/fragment/lightmap.glsl"
#include "/include/utility/color.glsl"
