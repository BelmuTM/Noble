/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/include/atmospherics/celestial.glsl"
#include "/include/fragment/brdf.glsl"
#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/reflections.glsl"
#include "/include/fragment/ao.glsl"
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

   vec3 shadowmap;
   #if SHADOWS == 0
      shadowmap = vec3(0.0);
   #else
      shadowmap = texture(colortex9, coords).rgb;
   #endif

   bool isWater    = getBlockId(texCoords) == 1;
   bool inWater    = isEyeInWater > 0.5;
   float depthDist = 0.0;

   // Props to SixthSurge#3922 for suggesting to use depthtex2 as the caustics texture
   #if WATER_CAUSTICS == 1
      bool canCast = inWater ? true : getBlockId(coords) == 1;
      if(canCast) { shadowmap *= waterCaustics(coords); }
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
   mat.albedo         = mix(opaques * mix(vec3(1.0), mat.albedo, mat.alpha), mat.albedo, mat.alpha) * transmittance;

   float ambientOcclusion = 1.0;
   #if AO == 1
      #if AO_TYPE == 0
         ambientOcclusion = computeSSAO(viewPos, mat.normal);
      #else
         ambientOcclusion = computeRTAO(viewPos, mat.normal);
      #endif
   #endif

   #if WHITE_WORLD == 1
	   mat.albedo = vec3(1.0);
   #endif

   /*DRAWBUFFERS:49*/
   gl_FragData[0] = vec4(mat.albedo, 1.0) + rain;
   gl_FragData[1] = vec4(shadowmap, ambientOcclusion);
}
