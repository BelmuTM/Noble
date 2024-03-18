/***********************************************/
/*          Copyright (C) 2024 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

/*
    [Credits]:
        Jessie - providing rod response coefficients for Purkinje (https://github.com/Jessie-LC)

    [References]:
		Hellsten, J. (2007). Evaluation of tone mapping operators for use in real time environments. http://www.diva-portal.org/smash/get/diva2:24136/FULLTEXT01.pdf
        Lagarde, S. (2014). Moving Frostbite to Physically Based Rendering 3.0. https://seblagarde.files.wordpress.com/2015/07/course_notes_moving_frostbite_to_pbr_v32.pdf
*/

/* RENDERTARGETS: 0 */

layout (location = 0) out vec3 color;

in vec2 textureCoords;

#include "/settings.glsl"
#include "/include/taau_scale.glsl"

#include "/include/common.glsl"

#include "/include/atmospherics/constants.glsl"

#if BLOOM == 1
    #include "/include/post/bloom/upsample.glsl"
#endif

#if TONEMAP == ACES
    #include "/include/post/aces/lib/splines.glsl"
    #include "/include/post/aces/lib/transforms.glsl"

    #include "/include/post/aces/lmt.glsl"
    #include "/include/post/aces/rrt.glsl"
    #include "/include/post/aces/odt.glsl"
#endif

#include "/include/post/exposure.glsl"
#include "/include/post/grading.glsl"

void main() {
    vec4 tmp = texture(MAIN_BUFFER, textureCoords);
    color    = tmp.rgb;

    #if DEBUG_HISTOGRAM == 1 && EXPOSURE == 2
    	if(all(lessThan(gl_FragCoord.xy, debugHistogramSize))) return;
	#endif

    float exposure = computeExposure(tmp.a);

    #if BLOOM == 1
        // https://google.github.io/filament/Filament.md.html#imagingpipeline/physicallybasedcamera/bloom
        color += computeBloom(textureCoords) * exp2(exposure + BLOOM_STRENGTH - 3.0);
    #endif

    #if PURKINJE == 1
        scotopicVisionApproximation(color);
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
