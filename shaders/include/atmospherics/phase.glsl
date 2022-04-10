/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

float rayleighPhase(float cosTheta) {
    const float rayleigh = 3.0 / (16.0 * PI);
    return rayleigh * (1.0 + pow2(cosTheta));
}

float cornetteShanksPhase(float cosTheta, float g) {
    const float cornette = 3.0 / (8.0 * PI);
    float gg             = pow2(g);

    float num   = (1.0 - gg) * (1.0 + pow2(cosTheta));
    float denom = (2.0 + gg) * pow(1.0 + gg - 2.0 * g * cosTheta, 1.5);
    return cornette * (num / denom);
}

float henyeyGreensteinPhase(float cosTheta, float g) {
    return (1.0 - pow2(g)) / pow(1.0 + pow2(g) - 2.0 * g * cosTheta, 1.5);
}

// Provided by Jessie#7257
float kleinNishinaPhase(float cosTheta, float e) {
    return e / (2.0 * PI * (e * (1.0 - cosTheta) + 1.0) * log(2.0 * e + 1.0));
}
