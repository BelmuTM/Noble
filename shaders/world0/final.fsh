/***********************************************/
/*       Copyright (C) Noble RT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/////////////// SETTINGS FILE ///////////////

#version 400 compatibility

varying vec2 texCoords;

#include "/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/frag/dither.glsl"
#include "/lib/frag/noise.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/util/utils.glsl"
#include "/lib/util/blur.glsl"
#include "/lib/util/color.glsl"
#include "/lib/util/worldTime.glsl"
#include "/lib/post/dof.glsl"
#include "/lib/post/outline.glsl"
#include "/lib/atmospherics/fog.glsl"

const vec4 fogColor = vec4(0.225, 0.349, 0.488, 0.5);
const float rainFogDensity = 0.09;

void main() {
    vec3 viewPos = getViewPos();
    vec4 Result = texture2D(colortex0, texCoords);
    float depth = texture2D(depthtex0, texCoords).r;

    Result += Fog(depth, viewPos, vec4(0.0), fogColor * vec4(getDayTimeColor(), 1.0), rainStrength, rainFogDensity); // Applying Fog

    // Depth Of Field
    vec3 depthOfField = Result.rgb;
    #if DOF == 1
        depthOfField = computeDOF(depth, viewPos);
    #endif
    Result = vec4(depthOfField, 1.0);

    // Bloom
    #if BLOOM == 1
        Result += bokeh(colortex7, 0.7 / viewSize, 8, 7.0) * BLOOM_INTENSITY;
    #endif
    
    vec3 exposureColor = Result.rgb * (EXPOSURE * PI);
    #if TONEMAPPING == 0
        Result.rgb = white_preserving_luma_based_reinhard(exposureColor); // Reinhard
    #elif TONEMAPPING == 1
        Result.rgb = uncharted2(exposureColor); // Uncharted 2
    #elif TONEMAPPING == 2
        Result.rgb = uchimura(exposureColor); // Uchimura
    #elif TONEMAPPING == 3
        Result.rgb = lottes(exposureColor); // Lottes
    #elif TONEMAPPING == 4
        Result.rgb = burgess(exposureColor); // Burgess
    #elif TONEMAPPING == 5
        Result.rgb = aces(exposureColor); // ACES
    #endif

    Result.rgb = vibrance_saturation(Result.rgb, VIBRANCE, SATURATION);
    Result.rgb = adjustContrast(Result.rgb, CONTRAST) + BRIGHTNESS;

    #if OUTLINE == 1
        Result = mix(Result, vec4(0.0), clamp(edgeDetection(OUTLINE_THICKNESS), 0.0, OUTLINE_DARKNESS));
    #endif

    #if VIGNETTE == 1
        float dist = distance(texCoords, vec2(0.5, 0.5));
        Result.rgb *= smoothstep(0.8, VIGNETTE_FALLOFF * 0.799, dist * (VIGNETTE_AMOUNT + VIGNETTE_FALLOFF));
    #endif

    /*DRAWBUFFERS:0*/
    Result.rgb = toSRGB(Result.rgb);
    gl_FragData[0] = Result;
}
