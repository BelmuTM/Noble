/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* DRAWBUFFERS:49 */

layout (location = 0) out vec4 albedo;
layout (location = 1) out vec4 shadowmap;

#include "/include/atmospherics/celestial.glsl"
#include "/include/fragment/brdf.glsl"
#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/reflections.glsl"
#include "/include/fragment/water.glsl"

void main() {
   vec4 rain    = RGBtoLinear(texture(colortex5, texCoords));
   vec3 viewPos = getViewPos0(texCoords);

   if(isSky(texCoords)) { return; }

   material mat = getMaterial(texCoords);
   mat.albedo   = RGBtoLinear(mat.albedo);
   vec3 opaques = RGBtoLinear(texture(colortex4, texCoords).rgb) * INV_PI;

   vec3 hitPos; vec2 coords = texCoords;

   #if REFRACTIONS == 1
      if(getBlockId(texCoords) > 0 && getBlockId(texCoords) <= 4) {
         opaques = simpleRefractions(viewPos, mat.normal, mat.F0, hitPos);
         coords  = hitPos.xy;
      }
   #endif

   shadowmap = texture(colortex9, coords);

   bool isWater    = getBlockId(texCoords) == 1;
   bool inWater    = isEyeInWater > 0.5;
   float depthDist = 0.0;

   // Props to SixthSurge#3922 for suggesting to use depthtex2 as the caustics texture
   #if WATER_CAUSTICS == 1
      bool canCast = inWater ? true : getBlockId(coords) == 1;
      if(canCast) { shadowmap.rgb *= waterCaustics(coords); }
   #endif

   if(isWater || inWater) {
      depthDist = inWater ? 

      length(transMAD3(gbufferModelViewInverse, viewPos))
      :
      distance(
	      transMAD3(gbufferModelViewInverse, viewPos),
		   transMAD3(gbufferModelViewInverse, getViewPos1(coords))
	   );
   }

   vec3 transmittance = inWater || isWater ? exp(-WATER_ABSORPTION_COEFFICIENTS * WATER_DENSITY * depthDist) : vec3(1.0);

   albedo.rgb  = mix(opaques * mix(vec3(1.0), mat.albedo, mat.alpha), mat.albedo, mat.alpha);
   albedo.rgb *= transmittance;

   albedo.a = 1.0;
   albedo  += rain;

   #if WHITE_WORLD == 1
	   albedo = vec4(1.0);
   #endif
}
