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
     return 1.0 / (exp2(EV100) * 1.2);
}

float computeExposure() {
     float EV100 = computeEV100();
     return EV100ToExposure(EV100);
}
