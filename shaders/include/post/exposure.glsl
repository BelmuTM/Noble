/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/*
const bool colortex0MipmapEnabled = true;
*/

#if EXPOSURE == 0
     float computeEV100() {
          return log2(pow2(APERTURE) / SHUTTER_SPEED * 100.0 / ISO);
     }
#else

     float computeAverageLuminance(sampler2D prevTex) {
          float currLuma = luminance(textureLod(colortex0, vec2(0.5), log2(max(viewResolution.x, viewResolution.y))).rgb);

          float previousLuma = texture(prevTex, vec2(0.5)).a;
          previousLuma       = previousLuma > 0.0 ? previousLuma : currLuma;

          float exposureTime      = currLuma > previousLuma ? 0.3 : 1.8; // <----- Concept from SixSeven#0150
          float exposureFrameTime = exp(-exposureTime * frameTime);
          return mix(currLuma, previousLuma, EXPOSURE == 0 ? 0.0 : exposureFrameTime);
     }

     float computeEV100fromLuma(float avgLuminance) {
          return log2(avgLuminance * S / K);
     }
#endif

float EV100ToExposure(float EV100) {
     return 1.0 / (1.2 * exp2(EV100));
}

float computeExposure(float avgLuminance) {
     float minExposure = PI / luminance(sunIlluminance);
     float maxExposure = 0.1 * PI / luminance(moonIlluminance);

     float EV100;
     #if EXPOSURE == 0
          EV100 = computeEV100();
     #else
          EV100 = computeEV100fromLuma(avgLuminance);
     #endif

     return max0(clamp(EV100ToExposure(EV100), minExposure, maxExposure));
}
