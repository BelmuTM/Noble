/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

#version 120

#define SSGI_BLUR 1 // [0 1]

varying vec2 texCoords;
varying vec2 lmCoords;

uniform vec3 cameraPosition;
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
uniform sampler2D colortex7;
uniform sampler2D depthtex0;

uniform sampler2D noisetex;

uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelView, gbufferModelViewInverse;

#include "/lib/util/noise.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/util/utils.glsl"
#include "/lib/util/gaussian.glsl"

void main() {
    vec3 viewPos = getViewPos();
    vec3 Normal = normalize(texture2D(colortex1, texCoords).rgb * 2.0 - 1.0);
    vec4 Result = texture2D(colortex0, texCoords);

    float F0 = texture2D(colortex2, texCoords).g;
    bool is_metal = (F0 * 255.0) > 229.5;

    float Depth = texture2D(depthtex0, texCoords).r;
    if(Depth == 1.0f) {
        gl_FragData[0] = Result;
        return;
    }
    vec3 Albedo = texture2D(colortex5, texCoords).rgb;
    vec4 GlobalIllumination = texture2D(colortex7, texCoords);

    #if SSGI_BLUR == 1
        GlobalIllumination = smartDeNoise(colortex7, texCoords, 5.0, 2.0, 0.5);
        GlobalIllumination = clamp(fastGaussian(colortex7, vec2(viewWidth, viewHeight), 5.0, 20.0, 15.0, GlobalIllumination), 0.0f, 1.0f);
    #endif

    Result.rgb += Albedo * (!is_metal ? GlobalIllumination.rgb : vec3(0.0));

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = Result;
}