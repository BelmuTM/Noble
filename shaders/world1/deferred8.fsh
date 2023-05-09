#version 400 compatibility

/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

in vec2 textureCoords;

#define STAGE_FRAGMENT
#define WORLD_END

#define ATROUS_PASS_INDEX 3
#include "/programs/deferred/atrous_pass.glsl"
