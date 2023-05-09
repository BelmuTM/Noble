/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

/*
    const bool colortex0MipmapEnabled = true;
*/

#include "/settings.glsl"
#include "/include/utility/uniforms.glsl"

#include "/include/utility/rng.glsl"
#include "/include/utility/math.glsl"
#include "/include/utility/color.glsl"

#include "/include/utility/transforms.glsl"
#include "/include/utility/phase.glsl"

#include "/include/utility/material.glsl"

#include "/include/atmospherics/constants.glsl"

//////////////////////////////////////////////////////////
/*-------------- MISC UTILITY FUNCTIONS ----------------*/
//////////////////////////////////////////////////////////

bool isSky(vec2 coords)  { return texture(depthtex0, coords).r == 1.0;                          }
bool isHand(vec2 coords) { return linearizeDepth(texture(depthtex0, coords).r) < MC_HAND_DEPTH; }

const vec2 hiZOffsets[] = vec2[](
	vec2(0.0, 0.0  ),
	vec2(0.5, 0.0  ),
    vec2(0.5, 0.25 ),
    vec2(0.5, 0.375)
);

float find2x2MinimumDepth(vec2 coords, int scale) {
    coords *= viewSize;

    return minOf(vec4(
        texelFetch(depthtex0, ivec2(coords)                      , 0).r,
        texelFetch(depthtex0, ivec2(coords) + ivec2(1, 0) * scale, 0).r,
        texelFetch(depthtex0, ivec2(coords) + ivec2(0, 1) * scale, 0).r,
        texelFetch(depthtex0, ivec2(coords) + ivec2(1, 1) * scale, 0).r
    ));
}

vec2 getDepthTile(vec2 coords, int lod) {
	return coords / exp2(lod) + hiZOffsets[lod - 1];
}
