#version 400 compatibility

#define STAGE_FRAGMENT

#include "/settings.glsl"

#define BLOOM_PASS_INDEX 0
#include "/include/post/bloom/downsample.glsl"
