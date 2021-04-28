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

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

#include "/lib/Util/math.glsl"
#include "/lib/Util/transforms.glsl"
#include "/lib/Util/util.glsl"
#include "/lib/Util/intersect.glsl"
#include "/lib/Lighting/ssr.glsl"

const float metallic = 0.0733f;

void main() {
    vec3 viewPos = getViewPos();
    vec3 Normal = normalize(texture2D(colortex1, TexCoords).rgb * 2.0f - 1.0f);

    vec4 Result = texture2D(colortex0, TexCoords);

    float blockId = getBlockId(colortex5);
    bool isReflective = true;
    bool isRaining = rainStrength > 0.0f;

    vec4 ssrt = vec4(0.0f);
    float ssrFactor = 0.0f;

    #if MC_VERSION >= 11300
    if(SSR == 1 && !isHandOrEntity()) {
        if(isRaining) ssrFactor = rainStrength;
        ssrFactor += float(isReflective);

        ssrt = simpleReflections(Result, viewPos, Normal, metallic);
    }
    #endif

    /* DRAWBUFFERS:012 */
    gl_FragData[0] = mix(Result, ssrt, ssrFactor);
}
