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

/*DRAWBUFFERS:09*/
void main() {
   vec4 rain    = RGBtoLinear(texture(colortex5, texCoords));
   vec3 viewPos = getViewPos0(texCoords);

   /*    ------- SKY -------    */

   #if WORLD == OVERWORLD
      if(isSky(texCoords)) {
         vec4 sky = vec4(0.0, 0.0, 0.0, 1.0);

         #if WORLD == OVERWORLD
            vec3 playerViewDir = normalize(mat3(gbufferModelViewInverse) * viewPos);
            vec3 starsColor    = blackbody(mix(STARS_MIN_TEMP, STARS_MAX_TEMP, rand(gl_FragCoord.xy)));

            vec3 tmp = texture(colortex7, projectSphere(playerViewDir) * ATMOSPHERE_RESOLUTION + (bayer2(gl_FragCoord.xy) * pixelSize)).rgb;
            sky.rgb  = tmp + (starfield(viewPos) * exp(-timeMidnight) * (STARS_BRIGHTNESS * 200.0) * starsColor);
            sky.rgb += celestialBody(normalize(viewPos), shadowDir);
         #endif

         gl_FragData[0] = sky + rain;
         gl_FragData[1] = vec4(0.0);
         return;
      }
   #endif

   material mat = getMaterial(texCoords);
   mat.albedo   = RGBtoLinear(mat.albedo).rgb;
   vec3 opaques = RGBtoLinear(texture(colortex4, texCoords)).rgb * INV_PI;

   vec3 hitPos; vec2 coords = texCoords;

   /*    ------- REFRACTIONS -------    */
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

   /*    ------- WATER CAUSTICS -------    */
   // Props to SixthSurge#3922 for suggesting to use depthtex2 as the caustics texture
   #if WATER_CAUSTICS == 1
      bool canCast = isEyeInWater == 1 ? true : getBlockId(coords) == 1;
      if(canCast) { shadowmap *= waterCaustics(coords); }
   #endif

   bool isWater    = getBlockId(texCoords) == 1;
   float depthDist = 0.0;

   /*    ------- WATER FOAM -------    */
   if(isWater || isEyeInWater == 1) {
      depthDist = isEyeInWater == 1 ? 

      length(transMAD3(gbufferModelViewInverse, viewPos))
      :
      distance(
	      transMAD3(gbufferModelViewInverse, viewPos),
		   transMAD3(gbufferModelViewInverse, getViewPos1(coords))
	   );

      opaques += WATER_FOAM == 0 ? 0.0 : waterFoam(depthDist);
   }

   /*    ------- WATER ABSORPTION -------    */
   vec3 transmittance = isWater || isEyeInWater == 1 ? exp(-depthDist * WATER_ABSORPTION_COEFFICIENTS) : vec3(1.0);
   opaques           *= transmittance;

   /*    ------- ALPHA BLENDING -------    */
   mat.albedo = mix(opaques * mix(vec3(1.0), mat.albedo, mat.alpha), mat.albedo, mat.alpha);

   /*    ------- AMBIENT OCCLUSION -------    */
   float ambientOcclusion = 1.0;
   #if AO == 1
      #if AO_TYPE == 0
         ambientOcclusion = computeSSAO(viewPos, mat.normal);
      #else
         ambientOcclusion = computeRTAO(viewPos, mat.normal);
      #endif
   #endif

   gl_FragData[0] = vec4(mat.albedo, 1.0) + rain;
   gl_FragData[1] = vec4(shadowmap, ambientOcclusion);
}
