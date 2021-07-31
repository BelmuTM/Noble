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
#include "/lib/frag/dither.glsl"
#include "/lib/frag/noise.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/util/utils.glsl"
#include "/lib/util/color.glsl"
#include "/lib/util/worldTime.glsl"
#include "/lib/material.glsl"
#include "/lib/lighting/brdf.glsl"
#include "/lib/lighting/raytracer.glsl"
#include "/lib/lighting/ssr.glsl"
#include "/lib/util/distort.glsl"
#include "/lib/lighting/shadows.glsl"

void main() {

   vec3 Shadow = vec3(1.0);
   #if SHADOWS == 1
      Shadow = shadowMap(getViewPos(), shadowMapResolution);
   #endif

   /*
      WATER ABSORPTION / REFRACTION
   */
   vec4 tex0 = texture2D(colortex0, texCoords);
   vec4 tex1 = texture2D(colortex1, texCoords);
   vec4 tex2 = texture2D(colortex2, texCoords);
   tex0.rgb = toLinear(tex0.rgb);
   material data = getMaterial(tex0, tex1, tex2);

   float depthDist = distance(
		linearizeDepth(texture2D(depthtex0, texCoords).r),
		linearizeDepth(texture2D(depthtex1, texCoords).r)
	);
   vec3 hitPos;
   vec3 opaques = texture2D(colortex4, texCoords).rgb;

   #if REFRACTION == 1
      vec3 viewPos = getViewPos();
      vec3 normal = normalize(decodeNormal(texture2D(colortex1, texCoords).xy));

      float NdotV = max(dot(normal, normalize(-viewPos)), 0.0);
      if(getBlockId(texCoords) > 0) opaques = simpleRefractions(viewPos, normal, NdotV, data.F0, hitPos);

      depthDist = distance(viewPos.z, hitPos.z);
   #endif

   // Alpha Blending
   data.albedo = mix(opaques, data.albedo, data.alpha);

   #if WHITE_WORLD == 0
      if(getBlockId(texCoords) == 1 && isEyeInWater == 0) {
         // Absorption
         depthDist = max(0.0, depthDist);
         float density = depthDist * 6.5e-1;

	      vec3 absorption = exp2(-(density / log(2.0)) * WATER_ABSORPTION_COEFFICIENTS);
         data.albedo *= absorption;

         // Foam
         #if WATER_FOAM == 1
            if(depthDist < FOAM_FALLOFF_DISTANCE * FOAM_EDGE_FALLOFF) {
               float falloff = (depthDist / FOAM_FALLOFF_DISTANCE) + FOAM_FALLOFF_BIAS;
               vec3 edge = absorption * falloff * FOAM_BRIGHTNESS * Shadow;

               float leading = depthDist / (FOAM_FALLOFF_DISTANCE * FOAM_EDGE_FALLOFF);
	            data.albedo = mix(data.albedo + edge, data.albedo, leading);
            }
         #endif
      }
   #endif

   /*DRAWBUFFERS:07*/
   gl_FragData[0] = vec4(data.albedo, 1.0);
   gl_FragData[1] = vec4(Shadow, 1.0);
}
