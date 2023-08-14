/***********************************************/
/*          Copyright (C) 2023 Belmu           */
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

#include "/include/taau_scale.glsl"
#include "/include/common.glsl"

#include "/include/atmospherics/constants.glsl"

#if BLOOM == 1
    #include "/include/utility/sampling.glsl"
    #include "/include/post/bloom.glsl"
#endif

#if TONEMAP == ACES
    #include "/include/post/aces/lib/splines.glsl"
    #include "/include/post/aces/lib/transforms.glsl"

    #include "/include/post/aces/rrt.glsl"
    #include "/include/post/aces/odt.glsl"
#endif

#include "/include/post/grading.glsl"

const float exposureBias = 1.0;

float minExposure = 1.0 * exposureBias / luminance(sunIrradiance);
float maxExposure = 0.1 * exposureBias / luminance(moonIrradiance);

float computeEV100fromLuminance(float luminance) {
    return log2(luminance * sensorSensitivity * exposureBias / calibration);
}

float computeExposureFromEV100(float ev100) {
    return 1.0 / (1.2 / exposureBias * exp2(ev100));
}

float computeExposure(float averageLuminance) {
	#if MANUAL_CAMERA == 1 || EXPOSURE == 0
		float ev100    = log2(pow2(F_STOPS) / (1.0 / SHUTTER_SPEED) * sensorSensitivity / ISO);
        float exposure = computeExposureFromEV100(ev100);
	#else
		float ev100	   = computeEV100fromLuminance(averageLuminance);
		float exposure = computeExposureFromEV100(ev100);
	#endif

	return clamp(exposure, minExposure, maxExposure);
}

void main() {
    vec4 tmp = texture(MAIN_BUFFER, textureCoords);
    color    = tmp.rgb;

    #if DEBUG_HISTOGRAM == 1 && EXPOSURE == 2
    	if(all(lessThan(gl_FragCoord.xy, debugHistogramSize))) return;
	#endif

    float exposure = computeExposure(tmp.a);

    #if BLOOM == 1
        // https://google.github.io/filament/Filament.md.html#imagingpipeline/physicallybasedcamera/bloom
        color += readBloom() * exp2(exposure + BLOOM_STRENGTH - 3.0);
    #endif

    #if PURKINJE == 1
        scotopicVisionApproximation(color);
    #endif

    color *= exposure;
    
    // Tonemapping & Color Grading
    
    #if TONEMAP == ACES        // ACES
        rrt(color);
        odt(color);
    #elif TONEMAP == 1         // Burgess
        burgess(color);
    #elif TONEMAP == 2         // Reinhard-Jodie
        reinhardJodie(color);
    #elif TONEMAP == 3         // Lottes
        lottes(color);
    #elif TONEMAP == 4         // Uchimura
        uchimura(color);
    #elif TONEMAP == 5         // Uncharted 2
        uncharted2(color);
    #endif

    #if TONEMAP != ACES
        color = linearToSrgb(color);
    #endif

    float vibranceMul   = 1.0 + VIBRANCE;
    float saturationMul = 1.0 + SATURATION;
    float contrastMul   = 1.0 + CONTRAST;
    float liftMul       = 0.1 * LIFT;
    float gammaMul      = 1.0 + GAMMA;
    float gainMul       = 1.0 + GAIN;

    whiteBalance( color);
    vibrance(color, vibranceMul);
    saturation(color, saturationMul);
    contrast(color, contrastMul);
    liftGammaGain(color, liftMul, gammaMul, gainMul);

    color = saturate(color);
}
