#version 400 compatibility

/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

in vec2 texCoords;

#define STAGE_FRAGMENT
#define WORLD_NETHER

#include "/include/common.glsl"
#include "/programs/deferred/deferred4.glsl"
