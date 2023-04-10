#version 400 compatibility

/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

out vec2 texCoords;

#define STAGE_VERTEX
#define WORLD_OVERWORLD

#include "/programs/deferred/atmosphere.glsl"
