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

float glowFwd(float ycIn, float glowGainIn, float glowMid) {
	if(ycIn <= 2.0 / 3.0 * glowMid) { return glowGainIn;                          }
	else if(ycIn >= 2.0 * glowMid)  { return 0.0;                                 } 
	else                            { return glowGainIn * (glowMid / ycIn - 0.5); }
}

float centerHue(float hue, float centerHue) {
	float hueCentered = hue - centerHue;
	return hueCentered < -180.0 ? hueCentered + 360.0 : hueCentered - 360.0;
}

void rrt(inout vec3 color) {
	// Convert to ACES2065-1
	color *= AP1_2_AP0_MAT;

	// --- Glow module --- //
	float saturation = rgbToSaturation(color);
	float ycIn       = rgbToYc(color);
	float s          = sigmoidShaper((saturation - 0.4) / 0.2);
	float addedGlow  = 1.0 + glowFwd(ycIn, RRT_GLOW_GAIN * s, RRT_GLOW_MID);

	color *= addedGlow;

	// --- Red modifier --- //
	float hue         = rgbToHue(color);
	float centeredHue = centerHue(hue, RRT_RED_HUE);
	float hueWeight   = cubicBasisShaper(centeredHue, RRT_RED_WIDTH);

	color.r += hueWeight * saturation * (RRT_RED_PIVOT - color.r) * (1.0 - RRT_RED_SCALE);

	color  = clamp16(max0(color) * AP0_2_AP1_MAT);			 // ACES to RGB rendering space
	color *= calcSatAdjustMatrix(RRT_SAT_FACTOR, AP1_RGB2Y); // Global desaturation

	// --- Apply the tonescale independently in rendering-space RGB --- //
	color.r = segmentedSplineC5Fwd(color.r);
	color.g = segmentedSplineC5Fwd(color.g);
	color.b = segmentedSplineC5Fwd(color.b);
}
