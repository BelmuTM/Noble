/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

/*
    [References]:
        Lagarde, S. (2013). Memo on Fresnel equations. https://seblagarde.wordpress.com/2013/04/29/memo-on-fresnel-equations/

    [Notes]:
        These two equations both assume a non-polarized input.
*/

vec3 fresnelDielectricDielectric_R(float cosThetaI, vec3 n1, vec3 n2) {
    vec3 eta       = n1 / n2;
    vec3 sinThetaT = eta * saturate(1.0 - cosThetaI * cosThetaI);
    vec3 cosThetaT = 1.0 - sinThetaT * sinThetaT;

    vec3 Rs = (n1 * cosThetaI - n2 * cosThetaT) / (n1 * cosThetaI + n2 * cosThetaT);
    vec3 Rp = (n1 * cosThetaT - n2 * cosThetaI) / (n1 * cosThetaT + n2 * cosThetaI);

    return saturate((Rs * Rs + Rp * Rp) * 0.5);
}

vec3 fresnelDielectricDielectric_T(float cosThetaI, vec3 n1, vec3 n2) {
    vec3 eta       = n1 / n2;
    vec3 sinThetaT = eta * saturate(1.0 - cosThetaI * cosThetaI);
    vec3 cosThetaT = 1.0 - sinThetaT * sinThetaT;

    if(any(greaterThan(sinThetaT, vec3(1.0)))) return vec3(1.0);

    vec3 numerator = 2.0 * n1 * cosThetaI;

    vec3 Ts = numerator / (n1 * cosThetaI + n2 * cosThetaT);
    vec3 Tp = numerator / (n1 * cosThetaT + n2 * cosThetaI);

    return saturate((Ts * Ts + Tp * Tp) * 0.5);
}

vec3 fresnelDielectricConductor(float cosTheta, vec3 eta, vec3 etaK) {  
   float cosThetaSq = cosTheta * cosTheta, sinThetaSq = 1.0 - cosThetaSq;
   vec3 etaSq = eta * eta, etaKSq = etaK * etaK;

   vec3 t0   = etaSq - etaKSq - sinThetaSq;
   vec3 a2b2 = sqrt(t0 * t0 + 4.0 * etaSq * etaKSq);
   vec3 t1   = a2b2 + cosThetaSq;
   vec3 t2   = 2.0 * sqrt(0.5 * (a2b2 + t0)) * cosTheta;
   vec3 Rs   = (t1 - t2) / (t1 + t2);

   vec3 t3 = cosThetaSq * a2b2 + sinThetaSq * sinThetaSq;
   vec3 t4 = t2 * sinThetaSq;   
   vec3 Rp = Rs * (t3 - t4) / (t3 + t4);

   return saturate((Rp + Rs) * 0.5);
}
