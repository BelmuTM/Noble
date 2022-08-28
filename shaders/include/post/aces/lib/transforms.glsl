/*************************************************************************/
/*                  License Terms for ACES Components                    */
/*                                                                       */
/*  ACES software and tools are provided by the Academy under the        */
/*  following terms and conditions: A worldwide, royalty-free,           */
/*  non-exclusive right to copy, modify, create derivatives, and         */
/*  use, in source and binary forms, is hereby granted, subject to       */
/*  acceptance of this license. Performance of any of the                */
/*  aforementioned acts indicates acceptance to be bound by the          */
/*  following terms and conditions:                                      */
/*                                                                       */
/*  Copyright © 2014 Academy of Motion Picture Arts and Sciences         */
/*  (A.M.P.A.S.). Portions contributed by others as indicated.           */
/*  All rights reserved.                                                 */
/*                                                                       */
/*  Copies of source code, in whole or in part, must retain the          */
/*  above copyright notice, this list of conditions and the              */
/*  Disclaimer of Warranty.                                              */
/*  Use in binary form must retain the above copyright notice,           */
/*  this list of conditions and the Disclaimer of Warranty in            */
/*  the documentation and/or other materials provided with the           */
/*  distribution.                                                        */
/*  Nothing in this license shall be deemed to grant any rights          */
/*  to trademarks, copyrights, patents, trade secrets or any other       */
/*  intellectual property of A.M.P.A.S. or any contributors, except      */
/*  as expressly stated herein.                                          */
/*  Neither the name “A.M.P.A.S.” nor the name of any other              */
/*  contributors to this software may be used to endorse or promote      */
/*  products derivative of or based on this software without express     */
/*  prior written permission of A.M.P.A.S. or the contributors, as       */
/*  appropriate.                                                         */
/*  This license shall be construed pursuant to the laws of the State    */
/*  of California, and any disputes related thereto shall be subject     */
/*  to the jurisdiction of the courts therein.                           */
/*                                                                       */
/*  Disclaimer of Warranty: THIS SOFTWARE IS PROVIDED BY A.M.P.A.S.      */
/*  AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES,      */
/*  INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF             */
/*  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND               */
/*  NON-INFRINGEMENT ARE DISCLAIMED. IN NO EVENT SHALL A.M.P.A.S.,       */
/*  OR ANY CONTRIBUTORS OR DISTRIBUTORS, BE LIABLE FOR ANY DIRECT,       */
/*  INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, RESTITUTIONARY, OR         */
/*  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT    */
/*  OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;      */
/*  OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF        */
/*  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT            */
/*  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE    */
/*  USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH     */
/*  DAMAGE.                                                              */
/*                                                                       */
/*  WITHOUT LIMITING THE GENERALITY OF THE FOREGOING, THE ACADEMY        */
/*  SPECIFICALLY DISCLAIMS ANY REPRESENTATIONS OR WARRANTIES WHATSOEVER  */
/*  RELATED TO PATENT OR OTHER INTELLECTUAL PROPERTY RIGHTS IN ACES,     */
/*  OR APPLICATIONS THEREOF, HELD BY PARTIES OTHER THAN A.M.P.A.S.,      */
/*  WHETHER DISCLOSED OR UNDISCLOSED.                                    */
/*************************************************************************/

vec3 linearToAP1(vec3 color) {
    return color * SRGB_2_AP1;
}

vec3 ap1ToLinear(vec3 color) {
    return (AP1_2_XYZ_MAT * color) * XYZ_2_SRGB_MAT;
}

vec3 srgbToAP1Albedo(vec3 color) {
    return srgbToLinear(color) * SRGB_2_AP1_ALBEDO;
}

vec3 xyzToXyV(vec3 XYZ) {  
    float divisor = max(XYZ[0] + XYZ[1] + XYZ[2], ACES_EPS);
    return vec3(XYZ.rg / divisor, XYZ.g);
}

vec3 xyYToXYZ(vec3 xyY) {
    vec3 XYZ;
    XYZ.r = xyY.r * xyY.b / max(xyY.g, ACES_EPS);
    XYZ.g = xyY.b;  
    XYZ.b = (1.0 - xyY.r - xyY.g) * xyY.b / max(xyY.g, ACES_EPS);

    return XYZ;
}

float rgbToSaturation(vec3 rgb) {
    return (max(maxOf(rgb), ACES_EPS) - max(minOf(rgb), ACES_EPS)) / max(maxOf(rgb), 1e-2);
}

float rgbToHue(vec3 rgb) {
    float hue;
    if(rgb[0] == rgb[1] && rgb[1] == rgb[2]) { hue = 0.0; }
    else { hue = (180.0 * RCP_PI) * atan(2.0 * rgb[0] - rgb[1] - rgb[2], sqrt(3.0) * (rgb[1] - rgb[2])); }
    
    return clamp(hue < 0.0 ? hue + 360.0 : hue, 0.0, 360.0);
}

const float ycRadiusWeight = 1.75;

float rgbToYc(vec3 rgb) {
    float r = rgb[0], g = rgb[1], b = rgb[2];
    float chroma = sqrt(b * (b - g) + g * (g - r) + r * (r - b));

    return (b + g + r + ycRadiusWeight * chroma) / 3.0;
}

mat3 calcSatAdjustMatrix(float sat, vec3 rgb2Y) {
    mat3 M;
    M[0][0] = (1.0 - sat) * rgb2Y[0] + sat;
    M[1][0] = (1.0 - sat) * rgb2Y[0];
    M[2][0] = (1.0 - sat) * rgb2Y[0];
  
    M[0][1] = (1.0 - sat) * rgb2Y[1];
    M[1][1] = (1.0 - sat) * rgb2Y[1] + sat;
    M[2][1] = (1.0 - sat) * rgb2Y[1];
  
    M[0][2] = (1.0 - sat) * rgb2Y[2];
    M[1][2] = (1.0 - sat) * rgb2Y[2];
    M[2][2] = (1.0 - sat) * rgb2Y[2] + sat;
    return M;
}
