#version 400 compatibility

/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

out vec2 texCoords;

#define STAGE_VERTEX
#include "/programs/composite/temporal.glsl"
