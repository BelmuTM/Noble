/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#if EXPOSURE == 1
     float computeAverageLuminance(sampler2D prevTex) {
          float currLuma = pow2(textureLod(colortex5, vec2(0.5), log2(maxOf2(viewSize))).a);

          float previousLuma = texelFetch(prevTex, ivec2(0), 0).a;
                previousLuma = previousLuma > 0.0 ? previousLuma : currLuma;

          float exposureTime      = currLuma > previousLuma ? EXPOSURE_SPEED_TO_BRIGHT : EXPOSURE_SPEED_TO_DARK;
          float exposureFrameTime = exp(-exposureTime * frameTime);
          return mix(currLuma, previousLuma, exposureFrameTime);
     }

     float computeEV100fromLuma(float avgLuminance) {
          return log2(avgLuminance * S / K);
     }
#endif

float EV100ToExposure(float EV100) {
     return 1.0 / (1.2 * exp2(EV100));
}

float computeExposure(float avgLuminance) {
     float minExposure = TAU / luminance(sunIlluminance);
     float maxExposure = 0.3 / luminance(moonIlluminance);

     float EV100;
     #if EXPOSURE == 0
          EV100 = log2(pow2(APERTURE) / (1.0 / SHUTTER_SPEED) * 100.0 / ISO);
     #else
          EV100 = computeEV100fromLuma(avgLuminance);
     #endif

     return clamp(EV100ToExposure(EV100), minExposure, maxExposure);
}
