#version 400 compatibility
#include "/include/extensions.glsl"

/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

varying vec2 texCoords;

#include "/settings.glsl"
#include "/include/common.glsl"
#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/shadows.glsl"
#include "/include/atmospherics/atmosphere.glsl"

/*
const int colortex4Format = RGBA16F;
const int colortex7Format = RGB16F;
const int colortex9Format = RGB16F;
*/

void main() {
     /*    ------- SHADOW MAPPING -------    */
     vec3 shadowmap = vec3(0.0);
     #if SHADOWS == 1
          shadowmap = shadowMap(getViewPos(texCoords));
     #endif

     /*    ------- ATMOSPHERIC SCATTERING -------    */
     vec3 sky = vec3(0.0);
     if(clamp(texCoords, vec2(0.0), vec2(ATMOSPHERE_RESOLUTION + 1e-2)) == texCoords) {
          vec3 rayDir = unprojectSphere(texCoords * (1.0 / ATMOSPHERE_RESOLUTION));
          sky = atmosphericScattering(atmosRayPos, rayDir);
     }

     /*DRAWBUFFERS:479*/
     gl_FragData[0] = sRGBToLinear(texture(colortex0, texCoords));
     gl_FragData[1] = vec4(sky, 1.0);
     gl_FragData[2] = vec4(shadowmap, 1.0);
}