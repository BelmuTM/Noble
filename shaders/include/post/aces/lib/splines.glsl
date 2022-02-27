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

float sigmoidShaper(float x) {
    float t = max0(1.0 - abs(0.5 * x));
    float y = 1.0 + sign(x) * (1.0 - t * t);
    return 0.5 * y;
}

float cubicBasisShaper(float x, float w) {

    const vec4 M[4] = vec4[4](
        vec4(-1.0 / 6.0, 3.0 / 6.0,-3.0 / 6.0, 1.0 / 6.0),
        vec4( 3.0 / 6.0,-6.0 / 6.0, 3.0 / 6.0, 0.0 / 6.0), 
        vec4(-3.0 / 6.0, 0.0 / 6.0, 3.0 / 6.0, 0.0 / 6.0), 
        vec4( 1.0 / 6.0, 4.0 / 6.0, 1.0 / 6.0, 0.0 / 6.0)
    );
  
    float knots[5] = float[5]( 
        w * -0.5,
        w * -0.25,
        0.0,
        w *  0.25,
        w *  0.5
    );
  
    float y = 0.0;

    if((x > knots[0]) && (x < knots[4])) {  
        float knotCoord = (x - knots[0]) * 4.0 / w;  
        int j   = int(knotCoord);
        float t = knotCoord - j;
      
        vec4 monomials = vec4(pow3(t), pow2(t), t, 1.0);

        switch(j) {
            case 3:  y = monomials[0] * M[0][0] + monomials[1] * M[1][0] + monomials[2] * M[2][0] + monomials[3] * M[3][0]; break;
            case 2:  y = monomials[0] * M[0][1] + monomials[1] * M[1][1] + monomials[2] * M[2][1] + monomials[3] * M[3][1]; break;
            case 1:  y = monomials[0] * M[0][2] + monomials[1] * M[1][2] + monomials[2] * M[2][2] + monomials[3] * M[3][2]; break;
            case 0:  y = monomials[0] * M[0][3] + monomials[1] * M[1][3] + monomials[2] * M[2][3] + monomials[3] * M[3][3]; break;
            default: y = 0.0; break;
        }
    }
    return y * 1.5;
}

const mat3 M = mat3(
     0.5,-1.0, 0.5,
    -1.0, 1.0, 0.5,
     0.5, 0.0, 0.0
);

struct SegmentedSplineParamsC5 {
    float coeffsLow[6];
    float coeffsHigh[6];
    vec2 minPoint;
    vec2 midPoint;
    vec2 maxPoint;
    float slopeLow;
    float slopeHigh;
};

struct SegmentedSplineParamsC9 {
    float coeffsLow[10];
    float coeffsHigh[10];
    vec2 minPoint;
    vec2 midPoint;
    vec2 maxPoint;
    float slopeLow;
    float slopeHigh;
};

const SegmentedSplineParamsC5 RRT_PARAMS = SegmentedSplineParamsC5(
    float[6](-4.0000000000,-4.0000000000,-3.1573765773,-0.4852499958, 1.8477324706, 1.8477324706), // coeffsLow[6]
    float[6](-0.7185482425, 2.0810307172, 3.6681241237, 4.0000000000, 4.0000000000, 4.0000000000), // coeffsHigh[6]
    vec2(0.18 * exp2(-15.0),   1e-4),                                                        // minPoint
    vec2(0.18,                  4.8),                                                        // midPoint  
    vec2(0.18 * exp2(18.0), 10000.0),                                                        // maxPoint
    0.0,                                                                                     // slopeLow
    0.0                                                                                      // slopeHigh
);

const SegmentedSplineParamsC9 ODT_48nits = SegmentedSplineParamsC9(
    float[10](-1.6989700043,-1.6989700043,-1.4779000000,-1.2291000000,-0.8648000000,-0.4480000000, 0.0051800000, 0.4511080334, 0.9113744414, 0.9113744414), // coeffsLow[10]
    float[10]( 0.5154386965, 0.8470437783, 1.1358000000, 1.3802000000, 1.5197000000, 1.5985000000, 1.6467000000, 1.6746091357, 1.6878733390, 1.6878733390), // coeffsHigh[10]
    vec2(0.18 * exp2(-6.5), 0.02),                                                                                                                   // minPoint
    vec2(0.18,               4.8),                                                                                                                   // midPoint  
    vec2(0.18 * exp2(6.5),  48.0),                                                                                                                   // maxPoint
    0.0,                                                                                                                                             // slopeLow
    0.04                                                                                                                                             // slopeHigh
);

float segmentedSplineC5Fwd(float x) {
    const SegmentedSplineParamsC5 C = RRT_PARAMS;
    const int N_KNOTS_LOW  = 4;
    const int N_KNOTS_HIGH = 4;

    float logX = log10(max(x, ACES_EPS)); 
    float logY;

    if(logX <= log10(C.minPoint.x)) { 

        logY = logX * C.slopeLow + (log10(C.minPoint.y) - C.slopeLow * log10(C.minPoint.x));

    } else if((logX > log10(C.minPoint.x)) && (logX < log10(C.midPoint.x))) {

        float knot_coord = (N_KNOTS_LOW - 1) * (logX - log10(C.minPoint.x)) / (log10(C.midPoint.x) - log10(C.minPoint.x));
        int j   = int(knot_coord);
        float t = knot_coord - j;

        vec3 coeffs    = vec3(C.coeffsLow[j], C.coeffsLow[j + 1], C.coeffsLow[j + 2]);
        vec3 monomials = vec3(pow2(t), t, 1.0);
        logY           = dot(monomials, M * coeffs);

    } else if((logX >= log10(C.midPoint.x)) && (logX < log10(C.maxPoint.x))) {

        float knot_coord = (N_KNOTS_HIGH - 1) * (logX - log10(C.midPoint.x)) / (log10(C.maxPoint.x) - log10(C.midPoint.x));
        int j   = int(knot_coord);
        float t = knot_coord - j;

        vec3 coeffs    = vec3(C.coeffsHigh[j], C.coeffsHigh[j + 1], C.coeffsHigh[j + 2]); 
        vec3 monomials = vec3(pow2(t), t, 1.0);
        logY           = dot(monomials, M * coeffs);

    } else {
        logY = logX * C.slopeHigh + (log10(C.maxPoint.y) - C.slopeHigh * log10(C.maxPoint.x));
    }
    return pow10(logY);
}

float segmentedSplineC9Fwd(float x) {
    SegmentedSplineParamsC9 C = ODT_48nits;
    const int N_KNOTS_LOW  = 8;
    const int N_KNOTS_HIGH = 8;

    C.minPoint.x = segmentedSplineC5Fwd(C.minPoint.x);
    C.midPoint.x = segmentedSplineC5Fwd(C.midPoint.x);
    C.maxPoint.x = segmentedSplineC5Fwd(C.maxPoint.x);

    float logX = log10(max(x, ACES_EPS));
    float logY;

    if(logX <= log10(C.minPoint.x)) { 

        logY = logX * C.slopeLow + (log10(C.minPoint.y) - C.slopeLow * log10(C.minPoint.x));

    } else if((logX > log10(C.minPoint.x)) && (logX < log10(C.midPoint.x))) {

        float knot_coord = (N_KNOTS_LOW - 1) * (logX - log10(C.minPoint.x)) / (log10(C.midPoint.x) - log10(C.minPoint.x));
        int j   = int(knot_coord);
        float t = knot_coord - j;

        vec3 coeffs    = vec3(C.coeffsLow[j], C.coeffsLow[j + 1], C.coeffsLow[j + 2]);
        vec3 monomials = vec3(pow2(t), t, 1.0);
        logY           = dot(monomials, M * coeffs);

    } else if((logX >= log10(C.midPoint.x)) && (logX < log10(C.maxPoint.x))) {

        float knot_coord = (N_KNOTS_HIGH - 1) * (logX - log10(C.midPoint.x)) / (log10(C.maxPoint.x) - log10(C.midPoint.x));
        int j   = int(knot_coord);
        float t = knot_coord - j;

        vec3 coeffs    = vec3(C.coeffsHigh[j], C.coeffsHigh[j + 1], C.coeffsHigh[j + 2]); 
        vec3 monomials = vec3(pow2(t), t, 1.0);
        logY           = dot(monomials, M * coeffs);

    } else { 
        logY = logX * C.slopeHigh + (log10(C.maxPoint.y) - C.slopeHigh * log10(C.maxPoint.x));
    }
    return pow10(logY);
}
