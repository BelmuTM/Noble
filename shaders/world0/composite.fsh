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
#include "/lib/util/worldTime.glsl"
#include "/lib/util/color.glsl"
#include "/lib/material.glsl"
#include "/lib/lighting/brdf.glsl"
#include "/lib/lighting/raytracer.glsl"
#include "/lib/lighting/ssr.glsl"
#include "/lib/util/distort.glsl"
#include "/lib/lighting/shadows.glsl"

void main() {
   vec4 temp = toLinear(texture2D(colortex4, texCoords));
   vec4 rain = texture2D(colortex5, texCoords);

   if(isSky(texCoords)) {
      /*DRAWBUFFERS:0*/
      gl_FragData[0] = temp + rain;
      return;
   }

   /*    ------- SHADOW MAPPING -------    */
   vec3 shadowmap = vec3(1.0);
   #if SHADOWS == 1
      shadowmap = shadowMap(getViewPos(texCoords), shadowMapResolution);
   #endif

   /*    ------- WATER ABSORPTION / REFRACTION -------    */
   vec4 tex0 = texture2D(colortex0, texCoords);
   vec4 tex1 = texture2D(colortex1, texCoords);
   vec4 tex2 = texture2D(colortex2, texCoords);
   material data = getMaterial(tex0, tex1, tex2);
   data.albedo = toLinear(tex0).rgb;

   float depthDist = distance(
		linearizeDepth(texture2D(depthtex0, texCoords).r),
		linearizeDepth(texture2D(depthtex1, texCoords).r)
	);
   vec3 hitPos;
   vec3 opaques = temp.rgb;

   #if REFRACTION == 1
      vec3 viewPos = getViewPos(texCoords);
      vec3 normal = normalize(decodeNormal(texture2D(colortex1, texCoords).xy));

      float NdotV = max(dot(normal, normalize(-viewPos)), 0.0);
      if(getBlockId(texCoords) > 0 && getBlockId(texCoords) <= 3) opaques = simpleRefractions(viewPos, normal, NdotV, data.F0, hitPos);

      depthDist = distance(viewPos.z, hitPos.z);
   #endif

   // Alpha Blending
   data.albedo = mix(opaques * mix(vec3(1.0), data.albedo, data.alpha), data.albedo, data.alpha);

   #if WHITE_WORLD == 0
      if(getBlockId(texCoords) == 1) {
         // Absorption
         depthDist = max(0.0, depthDist);
         float density = depthDist * 6.5e-1;

	      vec3 transmittance = exp2(-(density / log(2.0)) * WATER_ABSORPTION_COEFFICIENTS);
         data.albedo *= transmittance;

         // Foam
         #if WATER_FOAM == 1
            if(depthDist < FOAM_FALLOFF_DISTANCE * FOAM_EDGE_FALLOFF) {
               float falloff = (depthDist / FOAM_FALLOFF_DISTANCE) + FOAM_FALLOFF_BIAS;
               vec3 edge = transmittance * falloff * FOAM_BRIGHTNESS * shadowmap;

               float leading = depthDist / (FOAM_FALLOFF_DISTANCE * FOAM_EDGE_FALLOFF);
	            data.albedo = mix(data.albedo + edge, data.albedo, leading);
            }
         #endif
      }
   #endif

   /*DRAWBUFFERS:09*/
   gl_FragData[0] = vec4(data.albedo, 1.0) + rain;
   gl_FragData[1] = vec4(shadowmap, 1.0);
}
