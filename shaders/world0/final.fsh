/***********************************************/
/*       Copyright (C) Noble SSRT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/////////////// SETTINGS FILE ///////////////

#version 400 compatibility

varying vec2 texCoords;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex5;
uniform sampler2D depthtex0;
uniform sampler2D noisetex;

uniform vec3 cameraPosition;
uniform vec3 skyColor;
uniform float rainStrength;
uniform float centerDepthSmooth;
uniform int isEyeInWater;
uniform int worldTime;
uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float aspectRatio;
uniform float frameTimeCounter;

uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelView, gbufferModelViewInverse;

#include "/settings.glsl"
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
#include "/lib/post/bloom.glsl"
#include "/lib/atmospherics/fog.glsl"

const vec4 fogColor = vec4(0.225, 0.349, 0.488, 1.0);
const float rainFogDensity = 0.09;

void main() {
    vec3 viewPos = getViewPos();
    vec4 Result = texture2D(colortex0, texCoords);
    float Depth = texture2D(depthtex0, texCoords).r;

    Result += Fog(Depth, viewPos, vec4(0.0), fogColor * vec4(getDayTimeColor(), 1.0), rainStrength, rainFogDensity); // Applying Fog

    // Depth Of Field
    vec3 depthOfField = Result.rgb;
    #if DOF == 1
        depthOfField = computeDOF(Depth, viewPos);
    #endif
    Result = vec4(depthOfField, 1.0);

    // Bloom
    #if BLOOM == 1
        Result += Bloom(4, 3) * BLOOM_INTENSITY;
    #endif
    
    vec3 exposureColor = Result.rgb * EXPOSURE;
    #if TONEMAPPING == 0
        Result.rgb = reinhard_jodie(exposureColor); // Reinhard
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

    // Color Grading
    Result.rgb = vibrance_saturation(Result.rgb, VIBRANCE, SATURATION);
    Result.rgb = brightness_contrast(Result.rgb, CONTRAST, BRIGHTNESS);

    #if OUTLINE == 1
        Result = mix(Result, vec4(0.0), clamp(edgeDetection(), 0.0, OUTLINE_DARKNESS));
    #endif

    Result.rgb = toSRGB(Result.rgb);
    /*DRAWBUFFERS:0*/
    gl_FragData[0] = Result;
}
