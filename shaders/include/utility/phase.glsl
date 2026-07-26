/********************************************************************************/
/*                                                                              */
/*    Noble Shaders                                                             */
/*    Copyright (C) 2026  Belmu                                                 */
/*                                                                              */
/*    This program is free software: you can redistribute it and/or modify      */
/*    it under the terms of the GNU General Public License as published by      */
/*    the Free Software Foundation, either version 3 of the License, or         */
/*    (at your option) any later version.                                       */
/*                                                                              */
/*    This program is distributed in the hope that it will be useful,           */
/*    but WITHOUT ANY WARRANTY; without even the implied warranty of            */
/*    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the             */
/*    GNU General Public License for more details.                              */
/*                                                                              */
/*    You should have received a copy of the GNU General Public License         */
/*    along with this program.  If not, see <https://www.gnu.org/licenses/>.    */
/*                                                                              */
/********************************************************************************/

/*
    [Credits]:
        Jessie - providing the Klein-Nishina and biLambertianPlate phase functions (https://github.com/Jessie-LC)

    [References]:
        Nishita, T. (1993). Display of the earth taking into account atmospheric scattering. http://nishitalab.org/user/nis/cdrom/sig93_nis.pdf

    [Notes]:
        Phase functions represent the angular distribution of scattered radiation.
*/

const float isotropicPhase = 0.25 / PI;

float rayleighPhase(float cosTheta) {
    const float rayleighNormalization = 3.0 / (16.0 * PI);

    return rayleighNormalization * (1.0 + cosTheta * cosTheta);
}

float cornetteShanksPhase(float cosTheta, float g) {
    const float cornetteNormalization = 3.0 / (8.0 * PI);

    float gg = g * g;

    float numerator   = (1.0 - gg) * (1.0 + cosTheta * cosTheta);
    float denominator = (2.0 + gg) * pow(1.0 + gg - 2.0 * g * cosTheta, 1.5);

    return cornetteNormalization * (numerator / denominator);
}

float henyeyGreensteinPhase(float cosTheta, float g) {
    const float henyeyNormalization = 1.0 / (2.0 * TAU);

    return (1.0 - g * g) / pow(1.0 + g * g - 2.0 * g * cosTheta, 1.5) * henyeyNormalization;
}

float kleinNishinaPhase(float cosTheta, float e) {
    return e / (TAU * (e * (1.0 - cosTheta) + 1.0) * log(2.0 * e + 1.0));
}

// Phase function specifically designed for leaves
float biLambertianPlatePhase(float kd, float cosTheta) {
    const float bilambertNormalization = 1.0 / (3.0 * PI * PI);

    float phase = 2.0 * (-PI * kd * cosTheta + sqrt(1.0 - cosTheta * cosTheta) + cosTheta * acos(-cosTheta));

    return phase * bilambertNormalization;
}
