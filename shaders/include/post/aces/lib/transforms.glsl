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

/*
    Coefficients taken from:
    SixSeven: https://www.curseforge.com/minecraft/customization/voyager-shader-2-0
*/

const mat3 D60_2_D65_CAT = mat3(
	 0.98722400,-0.00611327, 0.01595330,
	-0.00759836, 1.00186000, 0.00533002,
	 0.00307257,-0.00509595, 1.08168000
);

const mat3 D65_2_D60_CAT = mat3(
	 1.01303000, 0.00610531,-0.01497100,
	 0.00769823, 0.99816500,-0.00503203,
	-0.00284131, 0.00468516, 0.92450700
);

const mat3 sRGB_2_XYZ_MAT = mat3(
	0.4124564, 0.3575761, 0.1804375,
	0.2126729, 0.7151522, 0.0721750,
	0.0193339, 0.1191920, 0.9503041
);

const mat3 XYZ_2_sRGB_MAT = mat3(
	 3.2409699419,-1.5373831776,-0.4986107603,
	-0.9692436363, 1.8759675015, 0.0415550574,
	 0.0556300797,-0.2039769589, 1.0569715142
);

const mat3 XYZ_2_AP0_MAT = mat3(
	 1.0498110175, 0.0000000000,-0.0000974845,
	-0.4959030231, 1.3733130458, 0.0982400361,
	 0.0000000000, 0.0000000000, 0.9912520182
);

const mat3 XYZ_2_AP1_MAT = mat3(
	 1.6410233797,-0.3248032942,-0.2364246952,
	-0.6636628587, 1.6153315917, 0.0167563477,
	 0.0117218943,-0.0082844420, 0.9883948585
);

const mat3 AP0_2_XYZ_MAT = mat3(
	0.9525523959, 0.0000000000, 0.0000936786,
	0.3439664498, 0.7281660966,-0.0721325464,
	0.0000000000, 0.0000000000, 1.0088251844
);

const mat3 AP1_2_XYZ_MAT = mat3(
	 0.6624541811, 0.1340042065, 0.1561876870,
	 0.2722287168, 0.6740817658, 0.0536895174,
	-0.0055746495, 0.0040607335, 1.0103391003
);

const mat3 AP0_2_AP1_MAT = mat3(
	 1.4514393161,-0.2365107469,-0.2149285693,
	-0.0765537734, 1.1762296998,-0.0996759264,
	 0.0083161484,-0.0060324498, 0.9977163014
);

const mat3 AP1_2_AP0_MAT = mat3(
	 0.6954522414, 0.1406786965, 0.1638690622,
	 0.0447945634, 0.8596711185, 0.0955343182,
    -0.0055258826, 0.0040252103, 1.0015006723
);

const mat3 XYZ_2_REC709_PRI_MAT = mat3(
     3.2409699419,-1.5373831776,-0.4986107603,
    -0.9692436363, 1.8759675015, 0.0415550574,
     0.0556300797,-0.2039769589, 1.0569715142
);

const vec3 AP1_RGB2Y = vec3(0.2722287168, 0.6740817658, 0.0536895174); // Desaturation Coefficients

const mat3 sRGB_2_AP0 = sRGB_2_XYZ_MAT * D65_2_D60_CAT * XYZ_2_AP0_MAT;
const mat3 sRGB_2_AP1 = sRGB_2_XYZ_MAT * D65_2_D60_CAT * XYZ_2_AP1_MAT;

const mat3 sRGB_2_AP1_ALBEDO = sRGB_2_XYZ_MAT * XYZ_2_AP1_MAT;

vec3 linearToAP1(vec3 color) {
    return color * sRGB_2_AP1;
}

vec3 sRGBToAP1Albedo(vec3 color) {
    return sRGBToLinear(color) * sRGB_2_AP1_ALBEDO;
}

vec3 XYZToxyY(vec3 XYZ) {  
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
