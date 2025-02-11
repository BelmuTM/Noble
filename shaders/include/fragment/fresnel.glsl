/********************************************************************************/
/*                                                                              */
/*    Noble Shaders                                                             */
/*    Copyright (C) 2025  Belmu                                                 */
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
        Jessie - providing beam ratio equation for transmission (https://github.com/Jessie-LC)

    [References]:
        Arnott, W.P. (2008). Fresnel equations. https://www.patarnott.com/atms749/pdf/FresnelEquations.pdf
        Lagarde, S. (2013). Memo on Fresnel equations. https://seblagarde.wordpress.com/2013/04/29/memo-on-fresnel-equations/
        Wikipedia. (2023). Snell's law. https://en.wikipedia.org/wiki/Snell%27s_law

    [Notes]:
        These two equations both assume a non-polarized input.
        I modified Snell's law to get the angle of refraction, I don't like calling it "Snell's law" because it was first
        discovered by a Persian scientist called Ibn-Sahl.
*/

vec3 calculateRefractedAngle(vec3 thetaI, vec3 n1, vec3 n2) {
    return asin((n1 / n2) * sin(thetaI));
}

vec3 fresnelDielectricDielectric_R(float cosThetaI, vec3 n1, vec3 n2) {
    vec3 thetaI = vec3(acos(cosThetaI));
    vec3 thetaT = calculateRefractedAngle(thetaI, n1, n2);

    vec3 cosThetaT = cos(thetaT);

    vec3 Rs = abs((n1 * cosThetaI - n2 * cosThetaT) / (n1 * cosThetaI + n2 * cosThetaT));
    vec3 Rp = abs((n1 * cosThetaT - n2 * cosThetaI) / (n1 * cosThetaT + n2 * cosThetaI));

    return saturate((Rs * Rs + Rp * Rp) * 0.5);
}

vec3 fresnelDielectricDielectric_T(float cosThetaI, vec3 n1, vec3 n2) {
    vec3 thetaI = vec3(acos(cosThetaI));
    vec3 thetaT = calculateRefractedAngle(thetaI, n1, n2);

    vec3 cosThetaT = cos(thetaT);

    if(any(greaterThan(abs(sin(thetaT)), vec3(1.0)))) return vec3(1.0);

    vec3 numerator = 2.0 * n1 * cosThetaI;

    vec3 Ts = abs(numerator / (n1 * cosThetaI + n2 * cosThetaT));
    vec3 Tp = abs(numerator / (n1 * cosThetaT + n2 * cosThetaI));

    vec3 beamRatio = abs((n2 * cosThetaT) / (n1 * cosThetaI));

    return saturate(beamRatio * (Ts * Ts + Tp * Tp) * 0.5);
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
