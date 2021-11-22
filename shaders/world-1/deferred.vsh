#version 400 compatibility
#include "/include/extensions.glsl"

/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

out vec2 texCoords;

#include "/settings.glsl"
#define WORLD NETHER
#define STAGE STAGE_VERTEX

#include "/include/uniforms.glsl"
#include "/programs/composite/deferred.glsl"
