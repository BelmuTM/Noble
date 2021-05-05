/*
  Author: Belmu (https://github.com/BelmuTM/)
  */

#version 120

#define SSGI 0 // [0 1]

varying vec2 TexCoords;
varying vec2 LightmapCoords;

uniform vec3 sunPosition, moonPosition, cameraPosition, skyColor;
uniform float viewWidth, viewHeight, rainStrength, near, far, aspectRatio, frameTimeCounter;
uniform int isEyeInWater, worldTime;

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
uniform mat4 shadowModelView, shadowProjection;

#include "/lib/Util/noise.glsl"
#include "/lib/Util/math.glsl"
#include "/lib/Util/transforms.glsl"
#include "/lib/Util/util.glsl"
#include "/lib/Util/raytracer.glsl"
#include "/lib/Lighting/ssgi.glsl"

void main() {
    vec3 viewPos = getViewPos();
    vec3 Normal = normalize(texture2D(colortex1, TexCoords).rgb * 2.0f - 1.0f);
    vec4 Result = texture2D(colortex0, TexCoords);

    vec3 GlobalIllumination = vec3(0.0f);
    #if SSGI == 1 && BLOOM != 1
        GlobalIllumination = computeSSGI(viewPos, Normal);
    #endif

    /* DRAWBUFFERS:06 */
    gl_FragData[0] = Result;
    gl_FragData[1] = vec4(GlobalIllumination, 1.0f);
}
