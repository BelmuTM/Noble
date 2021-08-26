/***********************************************/
/*       Copyright (C) Noble RT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#define APERTURE 1.4
#define ISO 250.0
#define SHUTTER_SPEED 1.0 / 70.0

float averageLuminance(sampler2D tex) {
     float minLum = 1.0, maxLum = 0.0;
     float LOD = ceil(log2(max(viewSize.x, viewSize.y)));

     vec3 color = textureLod(tex, vec2(0.5), LOD).rgb;
     float lum = luma(color);
     
     minLum = min(lum, minLum); maxLum = max(lum, maxLum);
     return clamp(lum, minLum, maxLum);
}
     
float computeEV100() {
     return log2((APERTURE * APERTURE) * SHUTTER_SPEED / (100.0 * ISO));
}

float computeEV100FromAverageLum(float averageLum) {
     const float K = 100.0 / 12.5; // Calibration
     return log2(averageLum * K);
}

float EV100ToExposure(float EV100) {
     return 1.0 / (1.2 * exp2(EV100));
}

vec3 applyExposure(sampler2D tex, vec3 color) {
     float EV100 = 0.0;
     
     #if AUTO_EXPOSURE == 1
           float averageLum = averageLuminance(tex);
           EV100 = computeEV100FromAverageLum(averageLum);
     #else
           EV100 = computeEV100();
     #endif
     
     return color * EV100ToExposure(EV100);
}
