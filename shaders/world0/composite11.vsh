#version 400 compatibility

#define STAGE_VERTEX

#include "/settings.glsl"

#define BLOOM_PASS_INDEX 3
#include "/include/post/bloom/downsample.glsl"
