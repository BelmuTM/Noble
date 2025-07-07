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
    [References]:
        Hellsten, J. (2007). Evaluation of tone mapping operators for use in real time environments. http://www.diva-portal.org/smash/get/diva2:24136/FULLTEXT01.pdf
        Lagarde, S. (2014). Moving Frostbite to Physically Based Rendering 3.0. https://seblagarde.files.wordpress.com/2015/07/course_notes_moving_frostbite_to_pbr_v32.pdf
        Guy, R., & Agopian, M. (2019). Physically Based Rendering in Filament. https://google.github.io/filament/Filament.md.html
*/

/* RENDERTARGETS: 0 */

layout (location = 0) out vec3 color;

in vec2 textureCoords;

#include "/settings.glsl"
#include "/include/taau_scale.glsl"

#include "/include/common.glsl"

#include "/include/atmospherics/constants.glsl"

#if TONEMAP == ACES
    #include "/include/post/aces/lib/parameters.glsl"

    #include "/include/post/aces/lib/splines.glsl"
    #include "/include/post/aces/lib/transforms.glsl"

    #include "/include/post/aces/lmt.glsl"
    #include "/include/post/aces/rrt.glsl"
    #include "/include/post/aces/odt.glsl"
#endif

#include "/include/utility/sampling.glsl"

#if LENS_FLARES == 1
    #include "/include/post/lens_flares.glsl"
#endif

#if GLARE == 1
    #include "/include/post/glare.glsl"
#endif

#include "/include/post/exposure.glsl"
#include "/include/post/grading.glsl"

void main() {
    color = texture(MAIN_BUFFER, textureCoords).rgb;

    #if DEBUG_HISTOGRAM == 1 && EXPOSURE == 2
        if (all(lessThan(gl_FragCoord.xy, debugHistogramSize)))
            return;
    #endif

    color = exp2(color) - 1.0;

    float exposure = computeExposure(texelFetch(HISTORY_BUFFER, ivec2(0), 0).a);

    #if BLOOM == 1
        vec3  bloom         = texture(IRRADIANCE_BUFFER, textureCoords * 0.5).rgb;
        float bloomStrength = exp2(exposure + BLOOM_STRENGTH - 3.0);

        color += bloom * bloomStrength;
    #endif

    #if PURKINJE == 1
        scotopicVisionApproximation(color);
    #endif

    #if LENS_FLARES == 1
        lensFlares(color, textureCoords);
    #endif

    #if GLARE == 1
        glare(color, textureCoords);
    #endif

    color *= exposure;
    
    // Tonemapping & Color Grading
    
    #if TONEMAP == 0           // AgX
        agx(color);
        agxLook(color);
        agxEotf(color);
    #elif TONEMAP == ACES      // ACES
        compressionLMT(color);
        rrt(color);
        odt(color);
    #elif TONEMAP == 2         // Burgess
        burgess(color);
    #elif TONEMAP == 3         // Reinhard-Jodie
        reinhardJodie(color);
    #elif TONEMAP == 4         // Lottes
        lottes(color);
    #elif TONEMAP == 5         // Uchimura
        uchimura(color);
    #elif TONEMAP == 6         // Uncharted 2
        uncharted2(color);
    #endif

    #if TONEMAP != ACES && TONEMAP != 0
        color = linearToSrgb(color);
    #endif

    color = saturate(color);

    const float vibranceMul   = 1.0 + VIBRANCE;
    const float saturationMul = 1.0 + SATURATION;
    const float contrastMul   = 1.0 + CONTRAST;
    const float liftMul       = 0.1 * LIFT;
    const float gammaMul      = 1.0 + GAMMA;
    const float gainMul       = 1.0 + GAIN;

    whiteBalance(color);
    vibrance(color, vibranceMul);
    saturation(color, saturationMul);
    contrast(color, contrastMul);
    liftGammaGain(color, liftMul, gammaMul, gainMul);
}
