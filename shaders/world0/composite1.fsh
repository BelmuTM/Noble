/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

#version 120

#define SSGI 1 // [0 1]

varying vec2 texCoords;
varying vec2 lmCoords;

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
#include "/lib/util/reprojection.glsl"
#include "/lib/lighting/raytracer.glsl"
#include "/lib/lighting/ssgi.glsl"

void main() {
    vec3 viewPos = getViewPos();
    vec3 Normal = normalize(texture2D(colortex1, texCoords).rgb * 2.0 - 1.0);
    vec4 Result = texture2D(colortex0, texCoords);

    vec3 GlobalIllumination = vec3(0.0f);
    #if SSGI == 1 && SSAO != 1
        GlobalIllumination = computeSSGI(viewPos, Normal);
    #endif

    /* DRAWBUFFERS:06 */
    gl_FragData[0] = Result;
    gl_FragData[1] = vec4(GlobalIllumination, 1.0);
}

