/***********************************************/
/*       Copyright (C) Noble RT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec4 Fog(float depth, vec3 viewPos, vec4 fogColorStart, vec4 fogColorEnd, float fogCoef, float density) {
    // Underwater Fog
    if(isEyeInWater == 1) {
        fogCoef = 1.0;
        density = 0.05;
        fogColorStart = vec4(0.0);
        fogColorEnd = vec4(0.145, 0.38, 0.42, 0.65) * density;
    }
    const float LOG2 = -1.442695;
    float d = density * (-viewPos.z - near);

    float fogDensity = 1.0 - clamp(exp2(d * d * LOG2), 0.0, 1.0);
    vec4 fogCol = mix(fogColorStart, fogColorEnd, fogDensity);

    return fogCol * fogCoef;
}
