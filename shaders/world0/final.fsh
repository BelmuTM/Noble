/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

#version 120

#define ABOUT 0 // [0]

#define DOF 1 // [0 1]
#define DOF_QUALITY 1 // [0 1]

#define BLOOM 0 // [0 1]
#define BLOOM_INTENSITY 0.5 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5]

#define OUTLINE 0 // [0 1]
#define EXPOSURE 1.00 // [0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]

#define VIBRANCE 1.00 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define SATURATION 1.00 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]

#define CONTRAST 1.00 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define BRIGHTNESS 0.00 // [-0.25 -0.20 -0.15 -0.10 -0.05 0.00 0.05 0.10 0.15 0.20 0.25]

varying vec2 texCoords;
uniform sampler2D colortex0;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D depthtex0;

uniform vec3 cameraPosition, skyColor;
uniform float rainStrength, centerDepthSmooth;
uniform int isEyeInWater;
uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;

uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelView, gbufferModelViewInverse;

#include "/lib/util/noise.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/util/utils.glsl"
#include "/lib/util/gaussian.glsl"
#include "/lib/post/dof.glsl"
#include "/lib/post/outline.glsl"
#include "/lib/post/bloom.glsl"
#include "/lib/atmospherics/fog.glsl"
#include "/lib/util/color.glsl"

const vec4 fogColor = vec4(0.225, 0.349, 0.888, 1.0);

void main() {
    vec4 Result = texture2D(colortex0, texCoords);
    float Depth = texture2D(depthtex0, texCoords).r;
    bool isSky = Depth == 1.0;
    vec4 skyColor4 = vec4(skyColor, 1.0);
    vec3 viewPos = getViewPos();

    Result = Fog(Depth, Result, viewPos, vec4(0.0), mix(fogColor, skyColor4, 0.5), rainStrength); // Applying Fog

    // Depth Of Field
    vec3 depthOfField = Result.rgb;
    #if DOF == 1
        if(DOF_QUALITY == 0) depthOfField = DOF1(Depth, viewPos);
        else depthOfField = DOF2(depthOfField, Depth, viewPos);
    #endif
    Result = vec4(depthOfField, 1.0);

    // Bloom
    #if BLOOM == 1 && SSGI != 1
        if(!isSky) Result = mix(Result, Bloom(Result.rgb, 4, 3), luma(Result.rgb) * BLOOM_INTENSITY);
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
    #endif

    // Color Grading
    Result.rgb = vibrance_saturation(Result.rgb, VIBRANCE, SATURATION);
    Result.rgb = brightness_contrast(Result.rgb, CONTRAST, BRIGHTNESS);

    #if OUTLINE == 1
        Result = mix(Result, vec4(0.0), edgeDetection());
    #endif

    Result.rgb = linearToSRGB(Result.rgb);
    gl_FragData[0] = Result;
}
