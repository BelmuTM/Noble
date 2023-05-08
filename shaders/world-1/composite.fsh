#version 400 compatibility

/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

in vec2 textureCoords;

#define STAGE_FRAGMENT
#define WORLD_NETHER

#include "/programs/composite/reflections_pass.glsl"
