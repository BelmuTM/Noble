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

float YTolinearCV(float y, float maxY, float minY) {
    return (y - minY) / (maxY - minY);
}

vec3 darkSurroundToDimSurround(vec3 linearCV) {
    vec3 xyY = XYZToxyY(linearCV * AP1_2_XYZ_MAT);
    xyY.b    = pow(clamp01(xyY.b), DIM_SURROUND_GAMMA);
    return xyYToXYZ(xyY) * XYZ_2_AP1_MAT;
}

// Gamma curves function
float bt1886_r(float L, float gamma, float Lw, float Lb) {
  float a = pow(pow(Lw, 1.0 / gamma) - pow( Lb, 1.0 / gamma), gamma);
  float b = pow(Lb, 1.0 / gamma) / (pow(Lw, 1.0 / gamma) - pow( Lb, 1.0 / gamma));
  float V = pow(max(L / a, 0.0), 1.0 / gamma) - b;
  return V;
}

void odt(inout vec3 color) {
    color = color * AP0_2_AP1_MAT; // OCES to RGB rendering space

    // Apply the tonescale independently in rendering-space RGB
    color.r = segmentedSplineC9Fwd(color.r);
    color.g = segmentedSplineC9Fwd(color.g);
    color.b = segmentedSplineC9Fwd(color.b);

    // Scale luminance to linear code value
    color.r = YTolinearCV(color.r, ODT_CINEMA_WHITE, ODT_CINEMA_BLACK);
    color.g = YTolinearCV(color.g, ODT_CINEMA_WHITE, ODT_CINEMA_BLACK);
    color.b = YTolinearCV(color.b, ODT_CINEMA_WHITE, ODT_CINEMA_BLACK);

    color = darkSurroundToDimSurround(color);                       // Apply gamma adjustment to compensate for dim surround
    color = color * calcSatAdjustMatrix(ODT_SAT_FACTOR, AP1_RGB2Y); // Apply desaturation to compensate for luminance difference

    color = color * AP1_2_XYZ_MAT; // Rendering space RGB to XYZ
    color = color * D60_2_D65_CAT; // Apply CAT from ACES white point to assumed observer adapted white point

    // CIE XYZ to display primaries and handling out-of-gamut values
    color = clamp01(color * XYZ_2_REC709_PRI_MAT);

    // Encode linear code values with transfer function
    color.r = bt1886_r(color.r, ODT_DISPGAMMA, ODT_LOW_WHITE, ODT_LOW_BLACK);
    color.g = bt1886_r(color.g, ODT_DISPGAMMA, ODT_LOW_WHITE, ODT_LOW_BLACK);
    color.b = bt1886_r(color.b, ODT_DISPGAMMA, ODT_LOW_WHITE, ODT_LOW_BLACK);
}
