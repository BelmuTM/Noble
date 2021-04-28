/*
  Author: Belmu (https://github.com/BelmuTM/)
  */

#version 120

#define ABOUT 0 // [0]

#define BLOOM 1 // [0 1]
#define BLOOM_INTENSITY 0.2 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
#define DOF 1 // [0 1]
#define DOF_QUALITY 0 // [0 1]
#define OUTLINE 0 // [0 1]
#define TONEMAPPING 1 // [0 1]

#define GAMMA 2.65 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00 2.05 2.10 2.15 2.20 2.25 2.30 2.35 2.40 2.45 2.50 2.55 2.60 2.65 2.70 2.75 2.80 2.85 2.90 2.95 3.00]

#define VIBRANCE 1.00 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define SATURATION 1.00 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]

#define CONTRAST 1.00 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define BRIGHTNESS 0.00 // [-0.25 -0.20 -0.15 -0.10 -0.05 0.00 0.05 0.10 0.15 0.20 0.25]

varying vec2 TexCoords;
uniform sampler2D colortex0;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D depthtex0;

uniform vec3 cameraPosition, skyColor;
uniform float viewWidth, viewHeight, near, far, rainStrength, centerDepthSmooth;
uniform int isEyeInWater;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;

#include "/lib/Util/math.glsl"
#include "/lib/Util/transforms.glsl"
#include "/lib/Util/util.glsl"
#include "/lib/Util/gaussian.glsl"
#include "/lib/PostEffects/bloom.glsl"
#include "/lib/PostEffects/dof.glsl"
#include "/lib/PostEffects/outline.glsl"
#include "/lib/PostEffects/fog.glsl"
#include "/lib/Util/color.glsl"

const vec4 fogColor = vec4(0.925f, 0.349f, 0.288f, 1.0f);

void main() {
    vec4 Result = texture2D(colortex0, TexCoords);
    float Depth = texture2D(depthtex0, TexCoords).r;
    vec3 viewPos = getViewPos();

    // Depth Of Field
    vec3 depthOfField = Result.rgb;
    if(DOF == 1) {
        if(DOF_QUALITY == 0) depthOfField = computeDOF(Depth, viewPos).rgb;
        else depthOfField = computeDOFHigh(depthOfField, Depth, viewPos);
    }
    Result = vec4(depthOfField, 1.0f);
    Result = computeFog(Depth, Result, viewPos, vec4(0.0f), vec4(skyColor, 1.0f)); // Applying Fog

    if(Depth == 1.0f) {
        gl_FragData[0] = Result;
        return;
    }

    if(TONEMAPPING == 0) Result = lumaBasedReinhardToneMapping(Result); // Reinhard Tonemapping
    else Result = uncharted2ToneMapping(Result); // Uncharted 2 Tonemapping

    // Bloom
    vec4 Bloom = vec4(0.0f);
    if(BLOOM == 1) Bloom = computeBloom(Result.rgb, 4, 3) * BLOOM_INTENSITY;
    Result += Bloom;

    // Color Grading
    Result.rgb = vibranceSaturation(Result.rgb, VIBRANCE, SATURATION);
    Result.rgb = brightnessContrast(Result.rgb, CONTRAST, BRIGHTNESS);

    Result = pow(Result, vec4(1.0f / GAMMA)); // Gamma Correction

    if(OUTLINE == 1) Result = mix(Result, vec4(0.0f), edgeDetection());

    gl_FragData[0] = Result;
}
