/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

#version 120

#define SHADOWS 1 // [0 1]
#define VL 1 // [0 1]

#define SPECULAR 1 // [0 1]
#define SPECULAR_BRDF 2 // [0 1 2]

#define SSAO 1 // [0 1]

varying vec2 texCoords;
varying vec2 LightmapCoords;

uniform vec3 sunPosition, moonPosition, cameraPosition, skyColor;
uniform float rainStrength, aspectRatio, frameTimeCounter;
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

/////////////// WATER ABSORPTION ///////////////
const float absorptionCoef = 0.9f;
const vec3 waterColor = vec3(0.1, 0.35f, 0.425f);

vec3 getDayTimeColor() {
    float wTimeF = float(worldTime);

	float timeSunrise = ((clamp(wTimeF, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(wTimeF, 0.0, 2000.0) / 2000.0));
	float timeNoon = ((clamp(wTimeF, 0.0, 2000.0)) / 2000.0) - ((clamp(wTimeF, 10000.0, 12000.0) - 10000.0) / 2000.0);
	float timeSunset = ((clamp(wTimeF, 10000.0, 12000.0) - 10000.0) / 2000.0) - ((clamp(wTimeF, 12500.0, 12750.0) - 12500.0) / 250.0);
	float timeMidnight = ((clamp(wTimeF, 12500.0, 12750.0) - 12500.0) / 250.0) - ((clamp(wTimeF, 23000.0, 24000.0) - 23000.0) / 1000.0);

    const vec3 ambient_sunrise = vec3(0.443, 0.572, 0.486);
    const vec3 ambient_noon = vec3(0.386, 0.502, 0.53);
    const vec3 ambient_sunset = vec3(0.943, 0.572, 0.247) * 0.26;
    const vec3 ambient_midnight = vec3(0.06, 0.088, 0.097);

    return ambient_sunrise * timeSunrise + ambient_noon * timeNoon + ambient_sunset * timeSunset + ambient_midnight * timeMidnight;
}

vec3 getDayTimeSunColor() {
    float wTimeF = float(worldTime);

	float timeSunrise = ((clamp(wTimeF, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(wTimeF, 0.0, 2000.0) / 2000.0));
	float timeNoon = ((clamp(wTimeF, 0.0, 2000.0)) / 2000.0) - ((clamp(wTimeF, 10000.0, 12000.0) - 10000.0) / 2000.0);
	float timeSunset = ((clamp(wTimeF, 10000.0, 12000.0) - 10000.0) / 2000.0) - ((clamp(wTimeF, 12500.0, 12750.0) - 12500.0) / 250.0);
	float timeMidnight = ((clamp(wTimeF, 12500.0, 12750.0) - 12500.0) / 250.0) - ((clamp(wTimeF, 23000.0, 24000.0) - 23000.0) / 1000.0);

    const vec3 sunColor_sunrise = vec3(0.49, 0.25, 0.024);
    const vec3 sunColor_noon = vec3(0.29, 0.255, 0.224);
    const vec3 sunColor_sunset = vec3(0.38, 0.18, 0.035);
    const vec3 sunColor_midnight = vec3(0.0);

    return sunColor_sunrise * timeSunrise + sunColor_noon * timeNoon + sunColor_sunset * timeSunset + sunColor_midnight * timeMidnight;
}

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

    return vec3(TorchLighting + SkyLighting + 0.026);
}

vec3 shadowMap() {
    vec3 viewPos = getViewPos();
    vec4 shadowSpace = viewToShadow(viewPos);
    vec3 sampleCoords = shadowSpace.xyz * 0.5 + 0.5;

    float randomAngle = texture2D(noisetex, texCoords * 20.0).r * 100.0;
    float cosTheta = cos(randomAngle);
    float sinTheta = sin(randomAngle);
    mat2 rotation =  mat2(cosTheta, -sinTheta, sinTheta, cosTheta) / shadowMapResolution;

    return blurShadows(rotation, sampleCoords);
}

void main() {
    vec3 viewPos = getViewPos();
    vec3 viewDir = normalize(-viewPos);
    vec3 lightPos = worldTime >= 12750 ? moonPosition : sunPosition;
    vec3 lightDir = normalize(lightPos);

    vec4 tex1 = texture2D(colortex0, texCoords);
    vec4 tex2 = texture2D(colortex1, texCoords);
    vec4 tex3 = texture2D(colortex2, texCoords);
    tex1.rgb = srgbToLinear(tex1.rgb);

    material data = getMaterial(tex1, tex2, tex3);

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

    /////////////// AMBIENT OCCLUSION ///////////////
    vec3 AmbientOcclusion = vec3(1.0);
    #if SSAO == 1 && SSGI != 1
        AmbientOcclusion = computeSSAO(viewPos, Normal);
    #endif

    /////////////// WATER ABSORPTION ///////////////
    /*
    if(isWater()) {
        float terrainDepth = Depth * 2.0 - 1.0;
        vec4 depthClipPos = gbufferProjectionInverse * vec4(texCoords * 2.0 - 1.0, terrainDepth, 1.0);
        float waterAlpha = 1.0 - exp2(-(absorptionCoef / log(2.0)) * distance(depthClipPos.xyz, viewToScreen(viewPos) * 2.0 - 1.0));
        
        vec4 waterResult = vec4(waterColor, waterAlpha);
        Result = waterResult;
        Albedo = waterResult.rgb;
    }
    */

    /* DRAWBUFFERS:05 */
    gl_FragData[0] = vec4(Lighting, 1.0f);
    gl_FragData[1] = vec4(data.albedo, AmbientOcclusion.r);
}
