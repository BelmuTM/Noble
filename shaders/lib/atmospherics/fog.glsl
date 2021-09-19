/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec3 fog(vec3 viewPos, vec3 fogColorStart, vec3 fogColorEnd, float fogCoef, float density) {
    const float sqrt2 = -sqrt(2.0);
    float d = density * pow(-viewPos.z - near, 0.6);

    float fogDensity = 1.0 - saturate(exp2(d * d * sqrt2));
    return mix(fogColorStart, fogColorEnd, fogDensity) * saturate(fogCoef);
}
