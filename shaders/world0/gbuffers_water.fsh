/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

#version 120

varying vec2 TexCoords;
varying vec2 LightmapCoords;
varying vec3 Normal;
varying vec4 Color;
varying vec3 viewPos;
varying float blockId;

uniform vec3 cameraPosition;

uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;

uniform sampler2D colortex0;
uniform sampler2D colortex3;
uniform sampler2D colortex6;

uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelView, gbufferModelViewInverse;

#include "/lib/util/noise.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/transforms.glsl"

const float absorptionCoef = 3.3f;
const vec3 waterColor = vec3(0.1, 0.35f, 0.425f);

int getBlockId() {
    return int(texture2D(colortex3, TexCoords).r * 255.0f + 0.5f);
}

void main() {
    vec4 Albedo = texture2D(colortex0, TexCoords) * Color;

    float terrainDepth = texture2D(colortex6, TexCoords).r * 2.0f - 1.0f;
    vec4 depthViewPos = gbufferProjectionInverse * vec4(TexCoords * 2.0f - 1.0f, terrainDepth, 1.0f);
    float waterAlpha = 1.0f - exp2(-(absorptionCoef / log(2.0f)) * distance(depthViewPos.xyz * 0.5f + 0.5f, viewToScreen(viewPos)));

    /*DRAWBUFFERS:012*/
    gl_FragData[0] = vec4(waterColor, waterAlpha);
    gl_FragData[1] = vec4(Normal * 0.5f + 0.5f, 1.0f);
    gl_FragData[2] = vec4(LightmapCoords, 0.0f, 1.0f);
}
