/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

#version 120

#define SSGI_TEMPORAL_ACCUMULATION 1 // [0 1]
#define SSGI_BLUR 1 // [0 1]

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
uniform sampler2D colortex7;
uniform sampler2D depthtex0;

uniform sampler2D shadowtex0, shadowtex1;
uniform sampler2D shadowcolor0;
uniform sampler2D noisetex;

uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView, gbufferPreviousProjection;
uniform mat4 shadowModelView, shadowProjection;

#include "/lib/util/noise.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/util/utils.glsl"
#include "/lib/util/gaussian.glsl"
#include "/lib/util/reprojection.glsl"
#include "/lib/lighting/raytracer.glsl"

const bool colortex7Clear = false;

void main() {
    vec3 viewPos = getViewPos();
    vec3 Normal = normalize(texture2D(colortex1, texCoords).rgb);
    vec4 Result = texture2D(colortex0, texCoords);

    float Depth = texture2D(depthtex0, texCoords).r;
    if(Depth == 1.0f) {
        gl_FragData[0] = Result;
        return;
    }

    vec3 Albedo = texture2D(colortex5, texCoords).rgb;
    float AmbientOcclusion = 0.0;

    // Blurring Ambient Occlusion
    int SAMPLES;
    for(int i = -4 ; i <= 4; i++) {
        for(int j = -3; j <= 3; j++) {
            vec2 offset = vec2((j * 1.0 / viewWidth), (i * 1.0 / viewHeight));
            AmbientOcclusion += texture2D(colortex5, texCoords + offset).a;
            SAMPLES++;
        }
    }
    AmbientOcclusion /= SAMPLES;

    vec4 GlobalIllumination = texture2D(colortex6, texCoords);
    vec4 GlobalIlluminationResult = GlobalIllumination;
    
    #if SSGI_TEMPORAL_ACCUMULATION == 1
        // Thanks Stubman#8195 for the help!
        vec3 reprojectedTexCoords = reprojection(vec3(texCoords, texture2D(depthtex0, texCoords).r));
        vec4 reprojectedGlobalIllumination = texture2D(colortex7, reprojectedTexCoords.xy);

        GlobalIlluminationResult = mix(GlobalIllumination, reprojectedGlobalIllumination, exp2(-1.0 * frameTime * 6.0f));
    #endif
    #if SSGI_BLUR == 1
        GlobalIlluminationResult = clamp(fastGaussian(colortex6, vec2(viewWidth, viewHeight), 2.45, 20.0, 15.0, GlobalIlluminationResult), 0.0f, 1.0f);
    #endif

    Result.rgb += Albedo * GlobalIlluminationResult.rgb;

    /* DRAWBUFFERS:07 */
    gl_FragData[0] = Result * AmbientOcclusion;
    gl_FragData[1] = GlobalIlluminationResult;
}
