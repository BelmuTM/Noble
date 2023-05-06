#version 400 compatibility

/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

in vec2 textureCoords;

#define STAGE_FRAGMENT
#define WORLD_OVERWORLD

#define ATROUS_PASS_INDEX 0
#include "/programs/deferred/atrous_pass.glsl"
