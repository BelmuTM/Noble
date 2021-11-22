/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/include/fragment/brdf.glsl"
#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/ssr.glsl"
#include "/include/atmospherics/atmosphere.glsl"

float wTime = float(worldTime);
float timeMidnight = ((clamp(wTime, 12500.0, 12750.0) - 12500.0) / 250.0) - ((clamp(wTime, 23000.0, 24000.0) - 23000.0) / 1000.0);

vec3 getCausticsViewPos(vec2 coords) {
   vec3 clipPos = vec3(coords, texture(depthtex1, coords).r) * 2.0 - 1.0;
   vec4 tmp = gbufferProjectionInverse * vec4(clipPos, 1.0);
   return tmp.xyz / tmp.w;
}

void main() {
   vec4 rain = sRGBToLinear(texture(colortex5, texCoords));
   vec3 viewPos = getViewPos(texCoords);

   if(isSky(texCoords)) {
      /*DRAWBUFFERS:0*/
      vec3 playerViewDir = normalize(mat3(gbufferModelViewInverse) * viewPos);

      vec4 tmp = texture(colortex7, projectSphere(playerViewDir) * ATMOSPHERE_RESOLUTION);            // Atmosphere
      vec4 sky = tmp + vec4(vec3((drawStars(viewPos) * STARS_BRIGHTNESS) * exp(-timeMidnight)), 1.0); // + Stars
      sky.rgb += sun(normalize(viewPos), shadowDir) * tmp.rgb;                                        // + Sun

      gl_FragData[0] = sky + rain;
      return;
   }

   /*    ------- WATER EFFECTS -------    */
   material mat = getMaterial(texCoords);
   mat.albedo = sRGBToLinear(vec4(mat.albedo, 1.0)).rgb;

   vec3 hitPos; vec2 coords = texCoords;
   vec3 opaques = texture(colortex4, texCoords).rgb * INV_PI * maxEps(dot(mat.normal, shadowDir));

   #if REFRACTION == 1
      if(F0toIOR(mat.F0) > 1.0 && getBlockId(texCoords) > 0 && getBlockId(texCoords) <= 4) {
         opaques = simpleRefractions(viewPos, mat.normal, mat.F0, hitPos);
         coords  = hitPos.xy;
      }
   #endif

   vec3 shadowmap = texture(colortex9, coords).rgb;

   /*    ------- CAUSTICS -------    */

   // Props to SixthSurge#3922 for suggesting to use depthtex2 as the caustics texture
   #if WATER_CAUSTICS == 1
      bool canCast = isEyeInWater == 1 ? true : getBlockId(coords) == 1;

      if(canCast) {
         vec2 worldPos = viewToWorld(getCausticsViewPos(coords)).xz * 0.5 + 0.5;
         float causticsSpeed = ANIMATED_WATER == 1 ? frameTimeCounter * WATER_CAUSTICS_SPEED : 0.0;
         vec3 caustics = texelFetch(depthtex2, ivec2(mod((worldPos * 80.0) + causticsSpeed, 250)), 0).rgb;
         shadowmap += caustics * WATER_CAUSTICS_STRENGTH * shadowmap;
      }
   #endif

   // Alpha Blending
   mat.albedo = mix(opaques * mix(vec3(1.0), mat.albedo, mat.alpha), mat.albedo, mat.alpha);

   float depthDist = abs(distance(
	   linearizeDepth(texture(depthtex0, coords).r),
		linearizeDepth(texture(depthtex1, coords).r)
	));

   #if WHITE_WORLD == 0
      if(getBlockId(texCoords) == 1) {
         // Transmittance
         float density = depthDist * 6.5e-1;
	      vec3 transmittance = exp2(-(density * 0.301029995) * WATER_ABSORPTION_COEFFICIENTS);
         if(isEyeInWater == 0) { mat.albedo *= transmittance; }

         // Foam
         #if WATER_FOAM == 1
            if(depthDist < FOAM_FALLOFF_DISTANCE * FOAM_EDGE_FALLOFF) {
               float falloff = (depthDist / FOAM_FALLOFF_DISTANCE) + FOAM_FALLOFF_BIAS;
               vec3 edge = transmittance * falloff * FOAM_BRIGHTNESS * shadowmap;

               float leading = depthDist / (FOAM_FALLOFF_DISTANCE * FOAM_EDGE_FALLOFF);
	            mat.albedo += edge * (1.0 - leading);
            }
         #endif
      }
   #endif

   /*DRAWBUFFERS:09*/
   gl_FragData[0] = clamp01(vec4(mat.albedo, 1.0) + rain);
   gl_FragData[1] = vec4(shadowmap, 1.0);
}
