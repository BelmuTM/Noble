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
    [References]:
        Uchimura, H. (2017). HDR Theory and practice. https://www.slideshare.net/nikuque/hdr-theory-and-practicce-jp
        Uchimura, H. (2017). GT Tonemap. https://www.desmos.com/calculator/gslcdxvipg?lang=fr
        Hable, J. (2017). Minimal Color Grading Tools. http://filmicworlds.com/blog/minimal-color-grading-tools/
        Taylor, M. (2019). Tone Mapping. https://64.github.io/tonemapping/
        Wikipedia. (2023). Von Kries coefficient law. https://en.wikipedia.org/wiki/Von_Kries_coefficient_law
        Wikipedia. (2023). LMS color space. https://en.wikipedia.org/wiki/LMS_color_space
        Wrensch, B. (2023). MINIMAL AGX IMPLEMENTATION. https://iolite-engine.com/blog_posts/minimal_agx_implementation
*/

//////////////////////////////////////////////////////////
/*--------------- TONEMAPPING OPERATORS ----------------*/
//////////////////////////////////////////////////////////

void whitePreservingReinhard(inout vec3 color, float white) {
    float luminance           = luminance(color);
    float toneMappedLuminance = luminance * (1.0 + luminance / (white * white)) / (1.0 + luminance);

    color *= toneMappedLuminance / luminance;
}

void reinhardJodie(inout vec3 color) {
    float luminance = luminance(color);
    vec3  tv        = color / (1.0 + color);

    color = mix(color / (1.0 + luminance), tv, tv);
}

void lottes(inout vec3 color) {
    const vec3 a      = vec3(1.6);   // Contrast
    const vec3 d      = vec3(0.977); // Shoulder contrast
    const vec3 hdrMax = vec3(8.0);   // White point
    const vec3 midIn  = vec3(0.18);
    const vec3 midOut = vec3(0.267);

    const vec3 b =
        (-pow(midIn, a) + pow(hdrMax, a) * midOut) /
        ((pow(hdrMax, a * d) - pow(midIn, a * d)) * midOut);
    const vec3 c =
        (pow(hdrMax, a * d) * pow(midIn, a) - pow(hdrMax, a) * pow(midIn, a * d) * midOut) /
        ((pow(hdrMax, a * d) - pow(midIn, a * d)) * midOut);

    color = pow(color, a) / (pow(color, a * d) * b + c);
}

vec3 uchimura(vec3 x, float P, float a, float m, float l, float c, float b) {
    float l0 = ((P - m) * l) / a;
    float L0 = m - m / a;
    float L1 = m + (1.0 - m) / a;
    float S0 = m + l0;
    float S1 = m + a * l0;
    float C2 = (a * P) / (P - S1);
    float CP = -C2 / P;

    vec3 w0 = vec3(1.0 - smoothstep(0.0, m, x));
    vec3 w2 = vec3(step(m + l0, x));
    vec3 w1 = vec3(1.0 - w0 - w2);

    vec3 T = vec3(m * pow(x / m, vec3(c)) + b);
    vec3 S = vec3(P - (P - S1) * exp(CP * (x - S0)));
    vec3 L = vec3(m + a * (x - m));

    return T * w0 + L * w1 + S * w2;
}

void uchimura(inout vec3 color) {
    const float P = 1.0;  // max display brightness
    const float a = 1.0;  // contrast
    const float m = 0.22; // linear section start
    const float l = 0.4;  // linear section length
    const float c = 1.33; // black
    const float b = 0.0;  // pedestal

    color = uchimura(color, P, a, m, l, c, b);
}

void uncharted2(inout vec3 color) {
    const float A = 0.15;
    const float B = 0.50;
    const float C = 0.10;
    const float D = 0.20;
    const float E = 0.02;
    const float F = 0.30;
    const float W = 11.2;

    float white = ((W * (A * W + C * B) + D * E) / (W * (A * W + B) + D * F)) - E / F;

    color  = ((color * (A * color + C * B) + D * E) / (color * (A * color + B) + D * F)) - E / F;
    color /= white;
}

void burgess(inout vec3 color) {
    vec3 maxColor = max(vec3(0.0), color - 0.004);
    
    color = (maxColor * (6.2 * maxColor + 0.05)) / (maxColor * (6.2 * maxColor + 2.3) + 0.06);
}

const mat3 agxTransform = mat3(
    0.842479062253094 , 0.0423282422610123, 0.0423756549057051,
    0.0784335999999992, 0.878468636469772 , 0.0784336,
    0.0792237451477643, 0.0791661274605434, 0.879142973793104
);

const mat3 agxTransformInverse = mat3(
     1.19687900512017  , -0.0528968517574562, -0.0529716355144438,
    -0.0980208811401368,  1.15190312990417  , -0.0980434501171241,
    -0.0990297440797205, -0.0989611768448433,  1.15107367264116
);

vec3 agxDefaultContrastApproximation(vec3 x) {
    vec3 x2 = x * x;
    vec3 x4 = x2 * x2;
    vec3 x6 = x4 * x2;

    return - 17.86     * x6 * x
           + 78.01     * x6
           - 126.7     * x4 * x
           + 92.06     * x4
           - 28.72     * x2 * x
           + 4.361     * x2
           - 0.1718    * x
           + 0.002857;
}

void agx(inout vec3 color) {
    const float minEv = -12.47393;
    const float maxEv =  4.026069;

    color = agxTransform * color;
    color = clamp(log2(color), minEv, maxEv);
    color = (color - minEv) / (maxEv - minEv);
    color = agxDefaultContrastApproximation(color);
}

void agxEotf(inout vec3 color) {
    color = agxTransformInverse * color;
}

void agxLook(inout vec3 color) {
    #if AGX_LOOK == 0
        // Default
        const vec3  slope      = vec3(1.0);
        const vec3  power      = vec3(1.0);
        const float saturation = 1.0;
    #elif AGX_LOOK == 1
        // Golden
        const vec3  slope      = vec3(1.0, 0.9, 0.5);
        const vec3  power      = vec3(0.8);
        const float saturation = 0.8;
    #elif AGX_LOOK == 2
        // Punchy
        const vec3  slope      = vec3(1.0);
        const vec3  power      = vec3(1.1);
        const float saturation = 1.2;
    #endif

    float luma = luminance(color);
  
    color = pow(color * slope, power);
    color = luma + saturation * (color - luma);
}

//////////////////////////////////////////////////////////
/*----------------------- GRADING ----------------------*/
//////////////////////////////////////////////////////////

mat3 chromaticAdaptationMatrix(vec3 source, vec3 destination) {
    vec3 sourceLMS      = source * CONE_RESP_CAT02;
    vec3 destinationLMS = destination * CONE_RESP_CAT02;
    vec3 tmp            = destinationLMS / sourceLMS;

    mat3 vonKries = mat3(
        tmp.x, 0.0, 0.0,
        0.0, tmp.y, 0.0,
        0.0, 0.0, tmp.z
    );

    return (CONE_RESP_CAT02 * vonKries) * inverse(CONE_RESP_CAT02);
}

void whiteBalance(inout vec3 color) {
    vec3 source           = toXYZ(blackbody(WHITE_BALANCE));
    vec3 destination      = toXYZ(blackbody(WHITE_POINT  ));
    mat3 chromaAdaptation = chromaticAdaptationMatrix(source, destination);

    color *= chromaAdaptation;
}

void vibrance(inout vec3 color, float intensity) {
    float minimum    = minOf(color);
    float maximum    = maxOf(color);
    float saturation = (1.0 - saturate(maximum - minimum)) * saturate(1.0 - maximum) * luminance(color) * 5.0;
    vec3  lightness  = vec3((minimum + maximum) * 0.5);

    // Vibrance
    color = mix(color, mix(lightness, color, intensity), saturation);
    // Negative vibrance
    color = mix(color, lightness, (1.0 - lightness) * (1.0 - intensity) * 0.5 * abs(intensity));
}

void saturation(inout vec3 color, float intensity) {
    color = mix(vec3(luminance(color)), color, intensity);
}

void contrast(inout vec3 color, float contrast) {
    color = max0((color - 0.5) * contrast + 0.5);
}

void liftGammaGain(inout vec3 color, float lift, float gamma, float gain) {
    vec3 lerpV = pow(color, vec3(gamma));
    color = gain * lerpV + lift * (1.0 - lerpV);
}
