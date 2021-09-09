/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

float averageLuminance() {
     float LOD = ceil(log2(max(viewSize.x, viewSize.y)));
     vec3 color = textureLod(colortex0, vec2(0.5) * pixelSize, LOD).rgb;
     return luma(color);
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
     return clamp(exposure, MIN_EXPOSURE, MAX_EXPOSURE);
}

float getExposureLuma(sampler2D prevTex) {
     float previousLuma = texture2D(prevTex, vec2(0.5) * pixelSize).r;
     return mix(averageLuminance(), previousLuma, exp(-frameTime * SHUTTER_SPEED));
}
