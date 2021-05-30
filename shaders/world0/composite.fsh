/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

#version 120

#define SHADOWS 1 // [0 1]
#define VL 1 // [0 1]
#define SPECULAR 1 // [0 1]
#define SSAO 1 // [0 1]

varying vec2 texCoords;
varying vec2 LightmapCoords;

uniform vec3 sunPosition, moonPosition, cameraPosition, skyColor;
uniform float rainStrength, aspectRatio, frameTimeCounter;
uniform int worldTime;
uniform int isEyeInWater;
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
uniform mat4 shadowModelView, shadowProjection;

#include "/lib/util/distort.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/util/noise.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/util/utils.glsl"
#include "/lib/material/labPBR.glsl"
#include "/lib/material/brdf.glsl"
#include "/lib/lighting/ssao.glsl"
#include "/lib/lighting/shadows.glsl"
#include "/lib/atmospherics/volumetric.glsl"
#include "/lib/util/color.glsl"

/*
const int colortex0Format = RGBA16F;
const int colortex1Format = RGB16;
const int colortex2Format = RGB16;
*/

/////////////// SETTINGS ///////////////
const float sunPathRotation = -40.0; // [80.0f 75.0f 70.0f 65.0f 60.0f 55.0f 50.0f 45.0f 40.0f 35.0f 30.0f 25.0f 20.0f 15.0f 10.0f 5.0f 0.0f -5.0f -10.0f -15.0f -20.0f -25.0f -30.0f -35.0f -40.0f -45.0f -50.0f -55.0f -60.0f -65.0f -70.0f -75.0f -80.0f]
const int shadowMapResolution = 4096; //[512 1024 2048 3072 4096 6144]
const int noiseTextureResolution = 64;
const float shadowDistanceRenderMul = 1.0;
const float ambientOcclusionLevel = 0.0;

/////////////// WORLD TIME ///////////////
float wTimeF = float(worldTime);
    float timeSunrise = ((clamp(wTimeF, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(wTimeF, 0.0, 2000.0) / 2000.0));
    float timeNoon = ((clamp(wTimeF, 0.0, 2000.0)) / 2000.0) - ((clamp(wTimeF, 10000.0, 12000.0) - 10000.0) / 2000.0);
    float timeSunset = ((clamp(wTimeF, 10000.0, 12000.0) - 10000.0) / 2000.0) - ((clamp(wTimeF, 12500.0, 12750.0) - 12500.0) / 250.0);
    float timeMidnight = ((clamp(wTimeF, 12500.0, 12750.0) - 12500.0) / 250.0) - ((clamp(wTimeF, 23000.0, 24000.0) - 23000.0) / 1000.0);

vec3 getDayTimeColor() {
    const vec3 ambient_sunrise = vec3(0.543, 0.272, 0.147);
    const vec3 ambient_noon = vec3(0.445, 0.402, 0.23);
    const vec3 ambient_sunset = vec3(0.543, 0.272, 0.147);
    const vec3 ambient_midnight = vec3(0.02, 0.1, 0.15);

    return ambient_sunrise * timeSunrise + ambient_noon * timeNoon + ambient_sunset * timeSunset + ambient_midnight * timeMidnight;
}

vec3 getDayTimeSunColor() {
    const vec3 sunColor_sunrise = vec3(0.30, 0.17, 0.045);
    const vec3 sunColor_noon = vec3(0.23, 0.26, 0.33);
    const vec3 sunColor_sunset = vec3(0.30, 0.17, 0.045);
    const vec3 sunColor_midnight = vec3(0.005, 0.05, 0.1);

    return sunColor_sunrise * timeSunrise + sunColor_noon * timeNoon + sunColor_sunset * timeSunset + sunColor_midnight * timeMidnight;
}

/////////////// LIGHTMAP ///////////////

float adjustLightmapTorch(in float torch) {
    const float K = 2.0;
    const float P = 5.06;
    return K * pow(torch, P);
}

float adjustLightmapSky(in float sky) {
    float sky_2 = sky * sky;
    sky_2 *= sky_2;
    return sky_2;
}

vec2 adjustLightmap(in vec2 Lightmap) {
    vec2 NewLightMap;
    NewLightMap.x = adjustLightmapTorch(Lightmap.x);
    NewLightMap.y = adjustLightmapSky(Lightmap.y);
    return NewLightMap;
}

vec3 getLightmapColor(in vec2 Lightmap) {
    Lightmap = adjustLightmap(Lightmap);
    vec3 TorchColor = vec3(1.5, 0.85, 0.88);

    vec3 TorchLighting = Lightmap.x * TorchColor;
    vec3 SkyLighting = Lightmap.y * getDayTimeColor();

    return vec3(TorchLighting + SkyLighting);
}

/////////////// SHADOWMAPPING ///////////////

vec3 shadowMap() {
    vec3 viewPos = getViewPos();
    vec4 shadowSpace = viewToShadow(viewPos);
    vec3 sampleCoords = shadowSpace.xyz * 0.5 + 0.5;

    float randomAngle = texture2D(noisetex, texCoords * 10.0).r;
    float cosTheta = cos(randomAngle);
    float sinTheta = sin(randomAngle);
    mat2 rotation =  mat2(cosTheta, -sinTheta, sinTheta, cosTheta) / shadowMapResolution;

    return blurShadows(sampleCoords, rotation);
}

void main() {
    vec3 viewPos = getViewPos();
    vec3 viewDir = normalize(-viewPos);
    vec3 lightPos = worldTime >= 12750 ? moonPosition : sunPosition;
    vec3 lightDir = normalize(lightPos);

    vec4 tex0 = texture2D(colortex0, texCoords);
    vec4 tex1 = texture2D(colortex1, texCoords);
    vec4 tex2 = texture2D(colortex2, texCoords);
    tex0.rgb = srgbToLinear(tex0.rgb);

    material data = getMaterial(tex0, tex1, tex2);

    vec3 Normal = normalize(data.normal.xyz);
    float Depth = texture2D(depthtex0, texCoords).r;
    if(Depth == 1.0) {
        gl_FragData[0] = vec4(data.albedo, 1.0);
        return;
    }

    /////////////// LIGHTMAP & SHADOWMAP ///////////////
    vec2 Lightmap = texture2D(colortex2, texCoords).zw;
    vec3 LightmapColor = getLightmapColor(Lightmap);

    vec3 Shadow = vec3(1.0);
    #if SHADOWS == 1
        Shadow = shadowMap();
    #endif

    /////////////// VOLUMETRIC LIGHTING ///////////////
    vec3 VolumetricLighting = vec3(0.0);
    #if VL == 1
        VolumetricLighting = getDayTimeSunColor() * computeVL(viewPos) * VL_BRIGHTNESS;
    #endif

    /////////////// BRDF LIGHTING ///////////////
    vec3 Lighting = BRDF_Lighting(Normal, viewDir, lightDir, data.albedo, data.roughness, data.F0, 
                    getDayTimeColor(), LightmapColor, Shadow, VolumetricLighting);

    vec4 Result = vec4(Lighting, 1.0);

    /////////////// AMBIENT OCCLUSION ///////////////
    vec3 AmbientOcclusion = vec3(1.0);
    #if SSAO == 1
        #if SSGI == 0
            AmbientOcclusion = computeSSAO(viewPos, Normal);
        #endif
    #endif

    /* DRAWBUFFERS:05 */
    gl_FragData[0] = Result;
    gl_FragData[1] = vec4(data.albedo, AmbientOcclusion.r);
}
