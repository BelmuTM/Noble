/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

const float K =  12.5; // Light meter calibration
const float S = 100.0; // Sensor sensitivity

float minExposure = PI  * rcp(luminance(sunIlluminance));
float maxExposure = 0.1 * rcp(luminance(moonIlluminance));

float computeEV100fromLuma(float luma) {
     return log2(luma * S / K);
}

float EV100ToExposure(float EV100) {
     return 1.0 * rcp(1.2 * exp2(EV100));
}

float computeExposure() {
     #if EXPOSURE == 0
          float EV100 = log2(pow2(APERTURE) / (1.0 / SHUTTER_SPEED) * 100.0 / ISO);
     #else
          float avgLuma = pow2(textureLod(colortex4, vec2(0.5), maxOf(ceil(log2(viewSize)))).a);
          float EV100   = computeEV100fromLuma(avgLuma);
     #endif

     float targetExposure = EV100ToExposure(EV100);
     float prevExposure   = texture(colortex8, vec2(0.5)).a;
           prevExposure   = prevExposure > 0.0 ? prevExposure : targetExposure;
           prevExposure   = clamp(prevExposure, minExposure, maxExposure);

     float exposureTime = targetExposure < prevExposure ? EXPOSURE_SPEED_TO_BRIGHT : EXPOSURE_SPEED_TO_DARK;
     return mix(targetExposure, prevExposure, exp(-exposureTime * frameTime));
}
