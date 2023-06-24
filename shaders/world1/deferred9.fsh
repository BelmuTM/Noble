#version 400 compatibility

#define STAGE_FRAGMENT
#define WORLD_END

#define ATROUS_PASS_INDEX 4
#include "/programs/deferred/atrous_pass.glsl"
