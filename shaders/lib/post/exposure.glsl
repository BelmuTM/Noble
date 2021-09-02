/***********************************************/
/*       Copyright (C) Noble RT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

float averageLuminance() {
     float LOD = ceil(log2(max(viewSize.x, viewSize.y)));

     vec3 color = textureLod(colortex0, vec2(0.5), LOD).rgb;
     return luma(color);
}

float averageLuminance2() {
     float minLum = 1.0, maxLum = 0.0;
     float totalLum = 0.0;
     
     vec2 samples = floor(viewSize / 20);

     for(int x = 0; x < samples.x; x++) {
          for(int y = 0; y < samples.y; y++) {
               vec3 color = texture2D(colortex0, (vec2(x, y) + 0.5) * pixelSize).rgb;
               float lum = luma(color);

               totalLum += lum;
               minLum = min(lum, minLum); maxLum = max(lum, maxLum);
          }
     }
     return totalLum / (samples.x * samples.y);
}

float computeEV100() {
     return log2((APERTURE * APERTURE) / (SHUTTER_SPEED) * 100.0 / (ISO));
}

float computeEV100fromLuma(float avgLuminance) {
     return log2(avgLuminance * (S / K));
}

float EV100ToExposure(float EV100) {
     return 1.0 / (exp2(EV100) * 1.2);
}

float computeExposure(float avgLuminance) {
     float EV100;
     #if AUTO_EXPOSURE == 0
          EV100 = computeEV100();
     #else
          EV100 = computeEV100fromLuma(avgLuminance);
     #endif

     float exposure = EV100ToExposure(EV100);
     return exposure;
}

float getExposureLuma(sampler2D prevTex) {
     float previousLuma = texture2D(prevTex, vec2(0.0)).r;
     return mix(averageLuminance(), previousLuma, exp(-frameTime * 30.0));
}
