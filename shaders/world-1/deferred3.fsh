#version 400 compatibility
#include "/include/extensions.glsl"

/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

in vec2 texCoords;

#define STAGE_FRAGMENT
#define WORLD_NETHER

#include "/include/common.glsl"
#include "/programs/composite/deferred3.glsl"
