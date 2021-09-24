/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#version 330

varying vec2 texCoords;

#include "/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/fragment/bayer.glsl"
#include "/lib/fragment/noise.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/util/utils.glsl"
#include "/lib/util/blur.glsl"
#include "/lib/post/bloom.glsl"
#include "/lib/util/worldTime.glsl"
#include "/lib/atmospherics/fog.glsl"

/*
const bool colortex5MipmapEnabled = true;
*/

void main() {
     vec3 viewPos = getViewPos(texCoords);
     vec4 Result = texture(colortex0, texCoords);

     Result.rgb += fog(viewPos, vec3(0.0), getDayColor(), (rainStrength * float(RAIN_FOG == 1)) + isEyeInWater, 0.05); // Applying Fog

     vec3 bloom = vec3(0.0);
     #if BLOOM == 1
          bloom = writeBloom();
     #endif

     /*DRAWBUFFERS:05*/
     gl_FragData[0] = Result;
     gl_FragData[1] = vec4(saturate(bloom), 1.0);
}
