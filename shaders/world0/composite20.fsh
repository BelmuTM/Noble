#version 400 compatibility

#define STAGE_FRAGMENT

#define BLOOM_UPSAMPLE_PASS
#define BLOOM_UPSAMPLE_PASS_INDEX 3

#include "/programs/post/bloom/tile_pass.glsl"
