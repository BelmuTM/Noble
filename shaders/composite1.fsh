/*
  Author: Belmu (https://github.com/BelmuTM/)
  */

#version 120

#define SSR 1 // [0 1]

varying vec2 TexCoords;
varying vec2 LightmapCoords;

uniform vec3 sunPosition, cameraPosition, skyColor;
uniform float viewWidth, viewHeight, rainStrength, near, far;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D depthtex0;

uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelView, gbufferModelViewInverse;

#include "/lib/Util/math.glsl"
#include "/lib/Util/transforms.glsl"
#include "/lib/Util/util.glsl"
#include "/lib/Util/raytracer.glsl"
#include "/lib/Lighting/ssr.glsl"

float reflectivity = 0.1365f;

void main() {
    vec3 viewPos = getViewPos();
    vec3 Normal = normalize(texture2D(colortex1, TexCoords).rgb * 2.0f - 1.0f);

    vec4 Result = texture2D(colortex0, TexCoords);

    int blockID = getBlockId();
    bool isReflective = isReflective();
    vec4 ssrt = vec4(0.0f);
    float ssrFactor = float(isReflective);

    #if MC_VERSION >= 11300 && SSR == 1
    if(!isHandOrEntity()) {
        ssrt = simpleReflections(Result, viewPos, Normal, reflectivity);
    }
    #endif

    /* DRAWBUFFERS:012 */
    gl_FragData[0] = Result + (ssrt * ssrFactor);
}
