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

float averageLuminance(sampler2D tex, int scale) {
     float minLum = 1.0, maxLum = 0.0;
     float totalLum = 0.0;
     
     vec2 samples = viewSize / scale;

     for(int x = 0; x < samples.x; x++) {
          for(int y = 0; y < samples.y; y++) {
               vec3 color = texture2D(tex, (vec2(x, y) + 0.5) * pixelSize).rgb;
               float lum = luma(color);

               totalLum += lum;
               minLum = min(lum, minLum); maxLum = max(lum, maxLum);
          }
     }
     return totalLum / samples.x * samples.y;
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
           float averageLum = averageLuminance(tex, 30);
           EV100 = computeEV100FromAverageLum(averageLum);
     #else
           EV100 = computeEV100();
     #endif
     
     return color * EV100ToExposure(EV100);
}
