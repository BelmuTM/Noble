#version 400 compatibility

/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

out vec2 texCoords;

#define STAGE_VERTEX
#define WORLD_OVERWORLD

#include "/include/common.glsl"

#if PRIMARY_CLOUDS == 1 || SECONDARY_CLOUDS == 1
    #include "/programs/deferred/deferred2.glsl"
#else
    #include "/programs/discard.glsl"
#endif
