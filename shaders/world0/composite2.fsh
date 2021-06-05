/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

#version 120

#define SSGI_TEMPORAL_ACCUMULATION 1 // [0 1]

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

const bool colortex7Clear = false;

vec4 getNeighborClampedColor(sampler2D currColorTex, vec4 prevColor) {
    vec4 minColor = vec4(10000.0); 
    vec4 maxColor = vec4(-10000.0); 

    for(int x = -2; x <= 2; x++) {
        for(int y = -2; y <= 2; y++) {
            vec4 currColor = texture2D(currColorTex, texCoords + vec2(x, y)); 

            minColor = min(minColor, currColor); 
            maxColor = max(maxColor, currColor); 
        }
    }
    minColor -= 0.075; 
    maxColor += 0.075; 
    
    return clamp(prevColor, minColor, maxColor); 
}

void main() {
    vec4 Result = texture2D(colortex0, texCoords);
    
    float Depth = texture2D(depthtex0, texCoords).r;
    if(Depth == 1.0) {
        gl_FragData[0] = Result;
        return;
    }
    vec3 viewPos = getViewPos();
    vec3 Normal = normalize(texture2D(colortex1, texCoords).rgb * 2.0 - 1.0);

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
        // Thanks Stubman#8195 and swr#1899 for the help!
        vec2 reprojectedTexCoords = reprojection(vec3(texCoords, texture2D(depthtex0, texCoords).r));
        vec4 reprojectedGlobalIllumination = getNeighborClampedColor(colortex6, texture2D(colortex7, reprojectedTexCoords));

        vec2 velocity = (texCoords - reprojectedTexCoords) * vec2(viewWidth, viewHeight);

        float blendFactor = float(
            reprojectedTexCoords.x > 0.0 && reprojectedTexCoords.x < 1.0 &&
            reprojectedTexCoords.y > 0.0 && reprojectedTexCoords.y < 1.0
        );
        blendFactor *= exp(-length(velocity)) * 0.35;
        blendFactor += 0.85;
        blendFactor = clamp(blendFactor, 0.01, 0.9790);

        GlobalIlluminationResult = mix(GlobalIllumination, reprojectedGlobalIllumination, blendFactor);
    #endif

    /* DRAWBUFFERS:07 */
    gl_FragData[0] = Result * AmbientOcclusion;
    gl_FragData[1] = GlobalIlluminationResult;
}
