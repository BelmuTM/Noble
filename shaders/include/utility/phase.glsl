/***********************************************/
/*          Copyright (C) 2024 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

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
    const float rayleigh = 3.0 / (16.0 * PI);
    return rayleigh * (1.0 + cosTheta * cosTheta);
}

float cornetteShanksPhase(float cosTheta, float g) {
    const float cornette = 3.0 / (8.0 * PI);
    float gg             = g * g;

    float num   = (1.0 - gg) * (1.0 + cosTheta * cosTheta);
    float denom = (2.0 + gg) * pow(1.0 + gg - 2.0 * g * cosTheta, 1.5);
    return cornette * (num / denom);
}

float henyeyGreensteinPhase(float cosTheta, float g) {
    return (1.0 - g * g) / pow(1.0 + g * g - 2.0 * g * cosTheta, 1.5) / (2.0 * TAU);
}

float kleinNishinaPhase(float cosTheta, float g) {
    float e = 1.0;
    for(int i = 0; i < 8; i++) {
        float gFromE = 1.0 / e - 2.0 / log(2.0 * e + 1.0) + 1.0;
        float deriv  = 4.0 / ((2.0 * e + 1.0) * pow2(log(2.0 * e + 1.0))) - 1.0 / (e * e);
        if(abs(deriv) < 1e-8) break;
        e = e - (gFromE - g) / deriv;
    }
    return e / (TAU * (e * (1.0 - cosTheta) + 1.0) * log(2.0 * e + 1.0));
}

// Phase function specifically designed for leaves
float biLambertianPlatePhase(in float kd, in float cosTheta) {
    float phase = 2.0 * (-PI * kd * cosTheta + sqrt(1.0 - cosTheta * cosTheta) + cosTheta * acos(-cosTheta));
    return phase / (3.0 * PI * PI);
}
