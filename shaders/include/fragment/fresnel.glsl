/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

/*
    [References]:
        Karis, B. (2013). Specular BRDF Reference. http://graphicrants.blogspot.com/2013/08/specular-brdf-reference.html
*/

float fresnelDielectric(float cosTheta, float n1, float n2) {
    float sinThetaT = (n1 / n2) * max0(1.0 - pow2(cosTheta));
    float cosThetaT = 1.0 - pow2(sinThetaT);

    if(sinThetaT >= 1.0) { return 1.0; }

    float sPolar = (n2 * cosTheta - n1 * cosThetaT) / (n2 * cosTheta + n1 * cosThetaT);
    float pPolar = (n2 * cosThetaT - n1 * cosTheta) / (n2 * cosThetaT + n1 * cosTheta);

    return saturate((pow2(sPolar) + pow2(pPolar)) * 0.5);
}

vec3 fresnelDielectric(float cosTheta, vec3 n1, vec3 n2) {
    vec3 sinThetaT = (n1 / n2) * max0(1.0 - pow2(cosTheta));
    vec3 cosThetaT = 1.0 - pow2(sinThetaT);

    vec3 sPolar = (n2 * cosTheta - n1 * cosThetaT) / (n2 * cosTheta + n1 * cosThetaT);
    vec3 pPolar = (n2 * cosThetaT - n1 * cosTheta) / (n2 * cosThetaT + n1 * cosTheta);

    return saturate((pow2(sPolar) + pow2(pPolar)) * 0.5);
}

vec3 fresnelDielectricConductor(float cosTheta, vec3 eta, vec3 etaK) {  
   float cosThetaSq = cosTheta * cosTheta;
   float sinThetaSq = 1.0 - cosThetaSq;
   vec3  eta2       = eta * eta;
   vec3  etaK2      = etaK * etaK;

   vec3 t0   = eta2 - etaK2 - sinThetaSq;
   vec3 a2b2 = sqrt(t0 * t0 + 4.0 * eta2 * etaK2);
   vec3 t1   = a2b2 + cosThetaSq;
   vec3 a    = sqrt(0.5 * (a2b2 + t0));
   vec3 t2   = 2.0 * a * cosTheta;
   vec3 Rs   = (t1 - t2) / (t1 + t2);

   vec3 t3 = cosThetaSq * a2b2 + sinThetaSq * sinThetaSq;
   vec3 t4 = t2 * sinThetaSq;   
   vec3 Rp = Rs * (t3 - t4) / (t3 + t4);

   return saturate((Rp + Rs) * 0.5);
}
