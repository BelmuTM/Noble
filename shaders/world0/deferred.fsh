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
const int colortex9Format = RGBA16F;
*/

void main() {
     vec3 viewPos = getViewPos(texCoords);

     /*    ------- SHADOW MAPPING -------    */
     vec3 shadowmap = vec3(0.0);
     #if SHADOWS == 1
          shadowmap = shadowMap(viewPos, shadowMapResolution);
     #endif

     /*    ------- CAUSTICS -------    */
     #if WATER_CAUSTICS == 1
          if(isEyeInWater == 1) {
               vec2 worldPos = viewToWorld(viewPos).xz * 0.5 + 0.5;
               float causticsSpeed = frameTimeCounter * WATER_CAUSTICS_SPEED;
               vec3 caustics = texelFetch(colortex9, ivec2(mod((worldPos * 80.0) + causticsSpeed, 250)), 0).rgb;
               shadowmap += caustics * WATER_CAUSTICS_STRENGTH * shadowmap;
          }
     #endif

     /*    ------- ATMOSPHERIC SCATTERING -------    */
     vec3 rayPos = vec3(0.0, earthRad + cameraPosition.y, 0.0);
     vec3 rayDir = unprojectSphere(texCoords);
     vec4 sky = vec4(atmosphericScattering(rayPos, rayDir), 1.0);

     /*DRAWBUFFERS:479*/
     gl_FragData[0] = sRGBToLinear(texture(colortex0, texCoords));
     gl_FragData[1] = sky;
     gl_FragData[2] = vec4(shadowmap, 1.0);
}