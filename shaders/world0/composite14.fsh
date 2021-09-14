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
#include "/lib/uniforms.glsl"
#include "/lib/fragment/bayer.glsl"
#include "/lib/fragment/noise.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/util/utils.glsl"
#include "/lib/util/blur.glsl"
#include "/lib/util/worldTime.glsl"
#include "/lib/atmospherics/fog.glsl"

void main() {
     vec3 viewPos = getViewPos(texCoords);
     vec4 Result = texture2D(colortex0, texCoords);

     Result.rgb += fog(viewPos, vec3(0.0), getDayColor(), (rainStrength * float(RAIN_FOG == 1)) + isEyeInWater, 0.05); // Applying Fog

     /*DRAWBUFFERS:0*/
     gl_FragData[0] = Result;
}
