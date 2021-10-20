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

/*
const int colortex4Format = RGBA16F;
const int colortex9Format = RGBA16F;
*/

void main() {
     vec3 viewPos = getViewPos(texCoords);
     vec3 normal = normalize(decodeNormal(texture(colortex1, texCoords).xy));

     /*    ------- SHADOW MAPPING -------    */
     vec3 shadowmap = vec3(0.0);
     #if SHADOWS == 1
          shadowmap = shadowMap(viewPos, shadowMapResolution);
     #endif

     #if WATER_CAUSTICS == 1
          if(isEyeInWater == 1) {
               vec2 worldPos = viewToWorld(viewPos).xz * 0.5 + 0.5;

               float causticsSpeed = frameTimeCounter * WATER_CAUSTICS_SPEED;
               vec3 caustics = texelFetch(colortex9, ivec2(mod((worldPos * 80.0) + causticsSpeed, 250)), 0).rgb;
               shadowmap += caustics * WATER_CAUSTICS_STRENGTH * shadowmap;
          }
     #endif

     /*DRAWBUFFERS:49*/
     if(isSky(texCoords)) {
          vec3 viewPos = getViewPos(texCoords);
          vec3 eyeDir = normalize(mat3(gbufferModelViewInverse) * viewPos);

          float VdotL = max(EPS, dot(normalize(viewPos), sunDir));
          float angle = quintic(0.9998, 0.99995, VdotL);

          vec3 sky = getDayTimeSkyGradient(eyeDir, viewPos) + (SUN_COLOR * angle); 
          gl_FragData[0] = vec4(sky, 1.0);
          return;
     } else {
          gl_FragData[0] = sRGBToLinear(texture(colortex0, texCoords));
     }
     gl_FragData[1] = vec4(shadowmap, 1.0);
}