/***********************************************/
/*       Copyright (C) Noble RT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#version 400 compatibility

varying vec2 texCoords;

#include "/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/fragment/noise.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/util/utils.glsl"
#include "/lib/util/blur.glsl"
#include "/lib/post/bloom.glsl"
#include "/lib/post/taa.glsl"

/*
const bool colortex5MipmapEnabled = true;
const int colortex7Format = RGBA16F;
const bool colortex7Clear = false;
*/

void main() {
     vec4 Result = texture2D(colortex0, texCoords);

     vec3 blur = vec3(0.0);
     #if BLOOM == 1
          blur  = bloomTile(2, vec2(0.0      , 0.0   ));
	     blur += bloomTile(3, vec2(0.0      , 0.26  ));
	     blur += bloomTile(4, vec2(0.135    , 0.26  ));
	     blur += bloomTile(5, vec2(0.2075   , 0.26  ));
	     blur += bloomTile(6, vec2(0.135    , 0.3325));
	     blur += bloomTile(7, vec2(0.160625 , 0.3325));
	     blur += bloomTile(8, vec2(0.1784375, 0.3325));
     #endif

     #if TAA == 1
          Result.rgb = clamp(computeTAA(colortex0, colortex7), 0.0, 1.0);
     #endif

     /*DRAWBUFFERS:075*/
     gl_FragData[0] = Result;
     gl_FragData[1] = Result;
     gl_FragData[2] = vec4(clamp(blur, 0.0, 1.0), 1.0);
}