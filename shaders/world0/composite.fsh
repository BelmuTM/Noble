/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

#version 120

#define SHADOWS 1 // [0 1]
#define VL 1 // [0 1]

#define SPECULAR 1 // [0 1]
#define SPECULAR_MODE 1 // [0 1]

#define SSAO 1 // [0 1]

varying vec2 TexCoords;
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
#include "/lib/lighting/brdf.glsl"
#include "/lib/lighting/ssao.glsl"
#include "/lib/lighting/shadows.glsl"
#include "/lib/atmospherics/volumetric.glsl"
#include "/lib/util/color.glsl"

/*
const int colortex0Format = RGBA16F;
const int colortex1Format = RGB16;
const int colortex2Format = RGB16;
*/

const float sunPathRotation = -40.0; // [80.0f 75.0f 70.0f 65.0f 60.0f 55.0f 50.0f 45.0f 40.0f 35.0f 30.0f 25.0f 20.0f 15.0f 10.0f 5.0f 0.0f -5.0f -10.0f -15.0f -20.0f -25.0f -30.0f -35.0f -40.0f -45.0f -50.0f -55.0f -60.0f -65.0f -70.0f -75.0f -80.0f]
const int shadowMapResolution = 3072; //[512 1024 2048 3072 4096 6144]
const int noiseTextureResolution = 64;
const float shadowDistanceRenderMul = 1.0;
const float ambientOcclusionLevel = 0.0;

const float shininess = 50.0;

vec3 getDayTimeColor() {
    float wTimeF = float(worldTime);

	float timeSunrise = ((clamp(wTimeF, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(wTimeF, 0.0, 2000.0) / 2000.0));
	float timeNoon = ((clamp(wTimeF, 0.0, 2000.0)) / 2000.0) - ((clamp(wTimeF, 10000.0, 12000.0) - 10000.0) / 2000.0);
	float timeSunset = ((clamp(wTimeF, 10000.0, 12000.0) - 10000.0) / 2000.0) - ((clamp(wTimeF, 12500.0, 12750.0) - 12500.0) / 250.0);
	float timeMidnight = ((clamp(wTimeF, 12500.0, 12750.0) - 12500.0) / 250.0) - ((clamp(wTimeF, 23000.0, 24000.0) - 23000.0) / 1000.0);

    const vec3 ambient_sunrise = vec3(0.843, 0.772, 0.586) * 0.9;
    const vec3 ambient_noon = vec3(0.686, 0.702, 0.63);
    const vec3 ambient_sunset = vec3(0.943, 0.772, 0.247) * 0.26;
    const vec3 ambient_midnight = vec3(0.06, 0.088, 0.097);

    return ambient_sunrise * timeSunrise + ambient_noon * timeNoon + ambient_sunset * timeSunset + ambient_midnight * timeMidnight;
}

vec3 getDayTimeSunColor() {
    float wTimeF = float(worldTime);

	float timeSunrise = ((clamp(wTimeF, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(wTimeF, 0.0, 2000.0) / 2000.0));
	float timeNoon = ((clamp(wTimeF, 0.0, 2000.0)) / 2000.0) - ((clamp(wTimeF, 10000.0, 12000.0) - 10000.0) / 2000.0);
	float timeSunset = ((clamp(wTimeF, 10000.0, 12000.0) - 10000.0) / 2000.0) - ((clamp(wTimeF, 12500.0, 12750.0) - 12500.0) / 250.0);
	float timeMidnight = ((clamp(wTimeF, 12500.0, 12750.0) - 12500.0) / 250.0) - ((clamp(wTimeF, 23000.0, 24000.0) - 23000.0) / 1000.0);

    const vec3 sunColor_sunrise = vec3(0.89, 0.655, 0.224);
    const vec3 sunColor_noon = vec3(1.25);
    const vec3 sunColor_sunset = vec3(0.98, 0.545, 0.235);
    const vec3 sunColor_midnight = vec3(0.986, 0.967, 0.94);

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

    return vec3(TorchLighting + SkyLighting);
}

vec3 shadowMap() {
    vec3 viewPos = getViewPos();
    vec4 shadowSpace = viewToShadow(viewPos);
    vec3 sampleCoords = shadowSpace.xyz * 0.5 + 0.5;

    float randomAngle = texture2D(noisetex, TexCoords * 20.0).r * 100.0;
    float cosTheta = cos(randomAngle);
    float sinTheta = sin(randomAngle);
    mat2 rotation =  mat2(cosTheta, -sinTheta, sinTheta, cosTheta) / shadowMapResolution;

    return blurShadows(rotation, sampleCoords);
}

void main() {
    vec3 viewPos = getViewPos();
    vec3 viewDir = normalize(-viewPos);
    vec3 Normal = normalize(texture2D(colortex1, TexCoords).rgb * 2.0 - 1.0);

    vec4 dayTimeSunColor = vec4(getDayTimeSunColor(), 1.0);

    vec4 Result = texture2D(colortex0, TexCoords);
    Result.rgb = srgbToLinear(Result.rgb); // Color Conversion

    vec2 Lightmap = texture2D(colortex2, TexCoords).rg;
    vec3 LightmapColor = getLightmapColor(Lightmap);

    #if VL == 1
        Result *= Result + vec4(computeVL(viewPos) * getDayTimeColor(), 1.0) * VL_BRIGHTNESS;
    #endif

    float Depth = texture2D(depthtex0, TexCoords).r;
    if(Depth == 1.0) {
        gl_FragData[0] = Result;
        return;
    }
    vec3 Albedo = Result.rgb;

    vec3 lightPos = worldTime >= 12750 ? moonPosition : sunPosition;
    vec3 lightDir = normalize(lightPos);
    float NdotL = max(dot(Normal, lightDir), 0.0);

    vec3 Shadow = vec3(1.0);
    #if SHADOWS == 1
        Shadow = shadowMap();
    #endif

    vec3 AmbientOcclusion = vec3(1.0);
    #if SSAO == 1 && SSGI != 1
        AmbientOcclusion = computeSSAO(viewPos, Normal);
    #endif

    vec3 Diffuse = Albedo * (LightmapColor + (NdotL * Shadow));
    vec3 Specular = vec3(0.0);
    vec3 specColor = mix(dayTimeSunColor.rgb, Albedo, 0.98) * Shadow;

    bool isSpecular = isSpecular();
    bool isRaining = rainStrength > 0.0;
    float rainFactor = 1.0;
    if(isRaining) rainFactor = rainStrength;

    #if MC_VERSION >= 11300 && SPECULAR == 1
    if(NdotL > 0.0 && !isHandOrEntity()) {
        float specFactor = 0.0;
        if(isRaining) specFactor = rainStrength;
        specFactor += float(isSpecular);

        #if SPECULAR_MODE == 0
            Specular = phongBRDF(lightDir, viewDir, Normal, specColor, shininess);
        #else
            Specular = blinnPhongBRDF(lightDir, viewDir, Normal, specColor, shininess);
        #endif
        Specular *= clamp(specFactor, 0.0, 1.0);
    }
    #endif

    Result = vec4(Diffuse + Specular, 1.0);

    /* DRAWBUFFERS:056 */
    gl_FragData[0] = Result;
    gl_FragData[1] = vec4(Albedo, AmbientOcclusion.r);
    gl_FragData[2] = vec4(vec3(0.0), Depth);
}
