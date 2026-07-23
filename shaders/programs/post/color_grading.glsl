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
        Hellsten, J. (2007). Evaluation of tone mapping operators for use in real time environments. http://www.diva-portal.org/smash/get/diva2:24136/FULLTEXT01.pdf
        Lagarde, S. (2014). Moving Frostbite to Physically Based Rendering 3.0. https://seblagarde.files.wordpress.com/2015/07/course_notes_moving_frostbite_to_pbr_v32.pdf
        Guy, R., & Agopian, M. (2019). Physically Based Rendering in Filament. https://google.github.io/filament/Filament.md.html
*/

/* RENDERTARGETS: 0 */

layout (location = 0) out vec3 colorOut;

in vec2 textureCoords;

#include "/settings.glsl"
#include "/include/taau_scale.glsl"

#include "/include/common.glsl"

#if TONEMAP == ACES

    #include "/include/post/aces/lib/parameters.glsl"

    #include "/include/post/aces/lib/splines.glsl"
    #include "/include/post/aces/lib/transforms.glsl"

    #include "/include/post/aces/lmt.glsl"
    #include "/include/post/aces/rrt.glsl"
    #include "/include/post/aces/odt.glsl"

#endif

#if LENS_FLARES == 1
    #include "/include/post/lens_flares.glsl"
#endif

#if GLARE == 1
    #include "/include/post/glare.glsl"
#endif

#include "/include/post/exposure.glsl"
#include "/include/post/grading.glsl"

void main() {
    
    colorOut = texture(MAIN_BUFFER, textureCoords).rgb;

    #if DEBUG_HISTOGRAM == 1 && EXPOSURE == 2
        if (all(lessThan(gl_FragCoord.xy, debugHistogramSize)))
            return;
    #endif

    float exposure = CURRENT_EXPOSURE();

    colorOut /= exposure;

    #if BLOOM == 1

        vec3  bloom         = texture(ILLUMINANCE_BUFFER, textureCoords * 0.5).rgb;
        float bloomStrength = exp2(exposure + BLOOM_STRENGTH - 3.0);

        if (isEyeInWater == 1) {
            bloom *= UNDERWATER_BLOOM_BOOST;
        }

        colorOut += bloom * bloomStrength;

    #endif

    #if PURKINJE == 1
        scotopicVisionApproximation(colorOut);
    #endif

    #if LENS_FLARES == 1
        lensFlares(colorOut, ILLUMINANCE_BUFFER, textureCoords);
    #endif

    #if GLARE == 1
        glare(colorOut, ILLUMINANCE_BUFFER, textureCoords);
    #endif

    colorOut *= exposure;
    
    // Tonemapping & Color Grading
    
    #if TONEMAP == 0           // AgX
        agx(colorOut);
        agxLook(colorOut);
        agxEotf(colorOut);
        
    #elif TONEMAP == ACES      // ACES
        compressionLMT(colorOut);
        rrt(colorOut);
        odt(colorOut);

    #elif TONEMAP == 2         // Burgess
        burgess(colorOut);

    #elif TONEMAP == 3         // Reinhard-Jodie
        reinhardJodie(colorOut);

    #elif TONEMAP == 4         // Lottes
        lottes(colorOut);

    #elif TONEMAP == 5         // Uchimura
        uchimura(colorOut);

    #elif TONEMAP == 6         // Uncharted 2
        uncharted2(colorOut);

    #endif

    #if TONEMAP != ACES && TONEMAP != 0
        colorOut = linearToSrgb(colorOut);
    #endif

    colorOut = saturate(colorOut);

    const float vibranceMul   = 1.0 + VIBRANCE;
    const float saturationMul = 1.0 + SATURATION;
    const float contrastMul   = 1.0 + CONTRAST;
    const float liftMul       = 0.1 * LIFT;
    const float gammaMul      = 1.0 + GAMMA;
    const float gainMul       = 1.0 + GAIN;

    whiteBalance(colorOut);
    vibrance(colorOut, vibranceMul);
    saturation(colorOut, saturationMul);
    contrast(colorOut, contrastMul);
    liftGammaGain(colorOut, liftMul, gammaMul, gainMul);
}
