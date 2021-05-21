/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

#version 120

#define SSGI_BLUR 1 // [0 1]

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

#include "/lib/util/noise.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/util/utils.glsl"
#include "/lib/util/gaussian.glsl"
#include "/lib/lighting/raytracer.glsl"

void main() {
    vec3 viewPos = getViewPos();
    vec3 Normal = normalize(texture2D(colortex1, TexCoords).rgb * 2.0f - 1.0f);
    vec4 Result = texture2D(colortex0, TexCoords);

    float Depth = texture2D(depthtex0, TexCoords).r;
    if(Depth == 1.0f) {
        gl_FragData[0] = Result;
        return;
    }

    vec3 Albedo = texture2D(colortex5, TexCoords).rgb;
    float AmbientOcclusion = 0.0f;

    // Blurring Ambient Occlusion
    int SAMPLES;
    for(int i = -4 ; i <= 4; i++) {
        for(int j = -3; j <= 3; j++) {
            vec2 offset = vec2((j * 1.0f / viewWidth), (i * 1.0f / viewHeight));
            AmbientOcclusion += texture2D(colortex5, TexCoords + offset).a;
            SAMPLES++;
        }
    }
    AmbientOcclusion /= SAMPLES;

    vec4 GlobalIllumination = texture2D(colortex6, TexCoords);
    // Blurring Global Illumination
    #if SSGI_BLUR == 1
        GlobalIllumination = fastGaussian(colortex6, vec2(viewWidth, viewHeight), 8.7f, 15.0f, 20.0f, GlobalIllumination);
    #endif

    Result.rgb += Albedo * GlobalIllumination.rgb;

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = Result * AmbientOcclusion;
}
