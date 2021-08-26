/***********************************************/
/*       Copyright (C) Noble RT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#define APERTURE 1.4
#define ISO 100.0
#define SHUTTER_SPEED 50.0
const float K = 12.5; // Light meter calibration
const float S = 100.0; // Sensor sensitivity

float averageLuminance() {
     float LOD = ceil(log2(max(viewSize.x, viewSize.y)));

     vec3 color = textureLod(colortex0, vec2(0.5), LOD).rgb;
     float lum = luma(color);
     
     return max(lum, 0.9);
}

#if AUTO_EXPOSURE == 0
float computeEV100() {
     return log2((APERTURE * APERTURE) / (SHUTTER_SPEED) * 100 / (ISO));
}

#else
float computeEV100() {
     return log2(averageLuminance() * (S / K));
}
#endif

float EV100ToExposure(float EV100) {
     return 1.0 / (1.2 * exp2(EV100));
}

float computeExposure() {
     float EV100 = computeEV100();
     return EV100ToExposure(EV100);
}
