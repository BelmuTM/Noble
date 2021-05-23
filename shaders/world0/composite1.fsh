/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

#version 120

#define SSGI 1 // [0 1]

varying vec2 TexCoords;
varying vec2 LightmapCoords;

uniform vec3 sunPosition, moonPosition, skyColor;
uniform vec3 cameraPosition, previousCameraPosition;
uniform float rainStrength, aspectRatio, frameTime;
uniform int isEyeInWater, worldTime;
uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D depthtex0;

uniform sampler2D shadowtex0, shadowtex1;
uniform sampler2D shadowcolor0;
uniform sampler2D noisetex;

uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView, gbufferPreviousProjection;
uniform mat4 shadowModelView, shadowProjection;

#include "/lib/util/dither.glsl"
#include "/lib/util/noise.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/util/utils.glsl"
#include "/lib/lighting/raytracer.glsl"
#include "/lib/lighting/ssgi.glsl"

// Written by Chocapic13
vec3 reprojection(vec3 pos) {
    pos = pos * 2.0f - 1.0f;

    vec4 viewPosPrev = gbufferProjectionInverse * vec4(pos, 1.0f);
    viewPosPrev /= viewPosPrev.w;
    viewPosPrev = gbufferModelViewInverse * viewPosPrev;

    vec3 cameraOffset = cameraPosition - previousCameraPosition;
    cameraOffset *= float(pos.z > 0.56f);

    vec4 previousPosition = viewPosPrev + vec4(cameraOffset, 0.0f);
    previousPosition = gbufferPreviousModelView * previousPosition;
    previousPosition = gbufferPreviousProjection * previousPosition;
    return previousPosition.xyz / previousPosition.w * 0.5f + 0.5f;
}

void main() {
    vec3 viewPos = getViewPos();
    vec3 Normal = normalize(texture2D(colortex1, TexCoords).rgb * 2.0f - 1.0f);
    vec4 Result = texture2D(colortex0, TexCoords);

    vec3 GlobalIllumination = vec3(0.0f);
    #if SSGI == 1
        GlobalIllumination = computeSSGI(viewPos, Normal);
    #endif

    vec3 reprojectedTexCoords = reprojection(vec3(TexCoords, texture2D(depthtex0, TexCoords).r));
    vec4 reprojectedGlobalIllumination = texture2D(colortex6, reprojectedTexCoords.xy);

    /* DRAWBUFFERS:067 */
    gl_FragData[0] = Result;
    gl_FragData[1] = vec4(GlobalIllumination, texture2D(colortex6, TexCoords).a);
    gl_FragData[2] = reprojectedGlobalIllumination;
}

