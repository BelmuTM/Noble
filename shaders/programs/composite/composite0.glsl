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
   vec4 rain = sRGBToLinear(texture(colortex5, texCoords));
   vec3 viewPos = getViewPos(texCoords);

   if(isSky(texCoords)) {
      /*DRAWBUFFERS:0*/
      vec4 sky = vec4(0.0, 0.0, 0.0, 1.0);

      #if WORLD == OVERWORLD
         vec3 playerViewDir = normalize(mat3(gbufferModelViewInverse) * viewPos);

         vec3 tmp = texture(colortex7, projectSphere(playerViewDir) * ATMOSPHERE_RESOLUTION + (bayer2(gl_FragCoord.xy) * pixelSize)).rgb;
         sky.rgb  = tmp + (starfield(viewPos) * STARS_BRIGHTNESS * exp(-timeMidnight));
         sky.rgb += celestialBody(normalize(viewPos), shadowDir);
      #endif

      gl_FragData[0] = sky + rain;
      return;
   }

   material mat = getMaterial(texCoords);
   mat.albedo   = sRGBToLinear(vec4(mat.albedo, 1.0)).rgb;

   vec3 hitPos; vec2 coords = texCoords;
   vec3 opaques = texture(colortex4, texCoords).rgb * INV_PI * maxEps(dot(mat.normal, shadowDir));

   /*    ------- REFRACTION -------    */
   #if REFRACTION == 1
      if(F0toIOR(mat.F0) > 1.0 && getBlockId(texCoords) > 0 && getBlockId(texCoords) <= 4) {
         opaques = simpleRefractions(viewPos, mat.normal, mat.F0, hitPos);
         coords  = hitPos.xy;
      }
   #endif

   vec3 shadowmap = SHADOWS == 0 ? vec3(0.0) : texture(colortex9, coords).rgb;

   /*    ------- WATER CAUSTICS -------    */
   // Props to SixthSurge#3922 for suggesting to use depthtex2 as the caustics texture
   #if WATER_CAUSTICS == 1
      bool canCast = isEyeInWater == 1 ? true : getBlockId(coords) == 1;
      if(canCast) { shadowmap *= waterCaustics(coords); }
   #endif

   bool isWater = getBlockId(texCoords) == 1;
   float depthDist = 0.0;

   /*    ------- WATER FOAM -------    */
   if(isWater) {
      depthDist = max0(distance(
	      linearizeDepth(texture(depthtex0, coords).r),
		   linearizeDepth(texture(depthtex1, coords).r)
	   ));

      opaques += WATER_FOAM == 0 ? 0.0 : waterFoam(depthDist);
   }

   // Alpha Blending
   mat.albedo = mix(opaques * mix(vec3(1.0), mat.albedo, mat.alpha), mat.albedo, mat.alpha);

   /*    ------- WATER ABSORPTION -------    */
   if(isWater) {
      // Transmittance
	   vec3 transmittance = exp2(-depthDist * WATER_ABSORPTION_COEFFICIENTS);
      mat.albedo *= transmittance;
   }

   float ambientOcclusion = 1.0;
   #if AO == 1
      ambientOcclusion = AO_TYPE == 0 ? computeSSAO(viewPos, mat.normal) : computeRTAO(viewPos, mat.normal);
   #endif

   /*DRAWBUFFERS:09*/
   gl_FragData[0] = vec4(mat.albedo, 1.0) + rain;
   gl_FragData[1] = vec4(shadowmap, ambientOcclusion);
}
