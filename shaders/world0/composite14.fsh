/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#version 330 compatibility

varying vec2 texCoords;

#include "/settings.glsl"
#include "/common.glsl"
#include "/lib/util/blur.glsl"
#include "/lib/post/bloom.glsl"
#include "/lib/atmospherics/fog.glsl"

/*
const bool colortex5MipmapEnabled = true;
*/

void main() {
     vec3 viewPos = getViewPos(texCoords);
     vec4 Result = texture(colortex0, texCoords);

     Result.rgb += fog(viewPos, vec3(0.0), viewPosSkyColor(viewPos), (rainStrength * float(RAIN_FOG == 1)) + isEyeInWater, 0.05); // Applying Fog

     vec3 bloom = vec3(0.0);
     #if BLOOM == 1
          bloom = writeBloom();
     #endif

     /*DRAWBUFFERS:05*/
     gl_FragData[0] = Result;
     gl_FragData[1] = vec4(saturate(bloom), 1.0);
}
