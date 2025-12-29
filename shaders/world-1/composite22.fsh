#version 400 compatibility

#define STAGE_FRAGMENT

#define BLOOM_UPSAMPLE_PASS
#define BLOOM_UPSAMPLE_PASS_INDEX 1

#include "/programs/post/bloom/tile_write.glsl"
