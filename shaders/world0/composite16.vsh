#version 400 compatibility

#define STAGE_VERTEX

#define BLOOM_UPSAMPLE_PASS
#define BLOOM_UPSAMPLE_PASS_INDEX 7

#include "/programs/post/bloom/tile_write.glsl"
