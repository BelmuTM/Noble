/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

const float K =  12.5; // Light meter calibration
const float S = 100.0; // Sensor sensitivity

float minExposure = PI  / luminance(sunIlluminance);
float maxExposure = 0.2 / luminance(moonIlluminance);

float EV100fromLuma(float luma) {
     return log2(luma * S / K);
}

float EV100ToExposure(float EV100) {
     return 1.0 / (1.2 * exp2(EV100));
}

#if EXPOSURE == 1
     float computeAvgLuminance() {
          float currLuma = exp2(textureLod(colortex4, vec2(0.5), ceil(log2(maxOf(viewSize)))).a);

          float prevLuma = texelFetch(colortex8, ivec2(0), 0).a;
                prevLuma = prevLuma > 0.0 ? prevLuma : currLuma;
                prevLuma = clamp(prevLuma, 2e-4, 4e4);

          float exposureTime = currLuma < prevLuma ? EXPOSURE_DARK_TO_BRIGHT : EXPOSURE_BRIGHT_TO_DARK;
          return mix(currLuma, prevLuma, exp(-exposureTime * frameTime));
     }
#endif
