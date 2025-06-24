#version 400 compatibility

#define STAGE_FRAGMENT

#define BLOOM_DOWNSAMPLE_PASS
#define BLOOM_DOWNSAMPLE_PASS_INDEX 2

#include "/programs/post/bloom/tile_pass.glsl"
