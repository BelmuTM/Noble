#version 400 compatibility
#include "/programs/extensions.glsl"

/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

varying vec2 texCoords;

#include "/settings.glsl"
#include "/programs/common.glsl"
#include "/lib/fragment/raytracer.glsl"
#include "/lib/fragment/shadows.glsl"
#include "/lib/atmospherics/atmosphere.glsl"

/*
const int colortex4Format = RGBA16F;
const int colortex7Format = RGB16F;
const int colortex9Format = RGB16F;
*/

void main() {
     /*    ------- SHADOW MAPPING -------    */
     vec3 shadowmap = vec3(0.0);
     #if SHADOWS == 1
          shadowmap = shadowMap(getViewPos(texCoords), shadowMapResolution);
     #endif

     /*    ------- ATMOSPHERIC SCATTERING -------    */
     vec4 sky = vec4(0.0);
     if(clamp(texCoords, vec2(0.0), vec2(ATMOSPHERE_RESOLUTION + 1e-3)) == texCoords) {
          vec3 rayDir = unprojectSphere(texCoords * (1.0 / ATMOSPHERE_RESOLUTION));
          sky = vec4(atmosphericScattering(atmosRayPos, rayDir), 1.0);
     }

     /*DRAWBUFFERS:479*/
     gl_FragData[0] = sRGBToLinear(texture(colortex0, texCoords));
     gl_FragData[1] = sky;
     gl_FragData[2] = vec4(shadowmap, 1.0);
}