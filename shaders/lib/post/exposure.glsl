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
     float minLum = 0.0, maxLum = 1.0;
     float totalLum = 0.0;

     vec2 resolution = vec2(viewWidth, viewHeight) * (1.0 / scale);

     for(int x = 0; x < resolution.x; x += scale) {
          for(int y = 0; y < resolution.y; y += scale) {
               vec3 color = texture2D(tex, (vec2(x, y) + 0.5) * pixelSize).rgb;
               float lum = luma(color);

               totalLum += lum;
               minLum = min(lum, minLum); maxLum = max(lum, maxLum);
          }
     }
     return totalLum / (resolution.x * resolution.y);
}
     
float computeEV100() {
     return log2((APERTURE * APERTURE) * SHUTTER_SPEED / (100.0 * ISO));
}

float computeEV100FromAverageLum(float averageLum) {
     const float K = 12.5; // Calibration
     return log2(averageLum * 100.0 / K);
}

float EV100ToExposure(float EV100) {
     return 1.0 / (1.2 * pow(2.0, EV100));
}

float computeExposure(sampler2D tex) {
     float EV100;
     
     #if AUTO_EXPOSURE == 1
           float averageLum = averageLuminance(tex, 50);
           EV100 = computeEV100FromAverageLum(averageLum);
     #else
           EV100 = computeEV100();
     #endif
     
     return EV100ToExposure(EV100);
}
