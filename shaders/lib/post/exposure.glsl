/***********************************************/
/*       Copyright (C) Noble RT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/
// placeholders
#define APERTURE 0.0
#define ISO 0.0
#define SHUTTER_SPEED 0.0

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

float computeEV() {
     return log2(((APERTURE * APERTURE) * SHUTTER_SPEED) / (100.0 * ISO);
}

float computeEVFromAverageLum(float averageLum) {
     const float K = 12.5; // metric calibration
     return log2(averageLum * 100.0 / K);
}
