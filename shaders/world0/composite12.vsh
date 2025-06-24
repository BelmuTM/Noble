#version 400 compatibility

#define STAGE_VERTEX

#define BLOOM_DOWNSAMPLE_PASS
#define BLOOM_DOWNSAMPLE_PASS_INDEX 5

#include "/programs/post/bloom/tile_pass.glsl"
