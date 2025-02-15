#version 400 compatibility

#define STAGE_VERTEX

#define BLOOM_DOWNSAMPLE_PASS
#define BLOOM_DOWNSAMPLE_PASS_INDEX 3

#include "/include/post/bloom/tile_pass.glsl"
