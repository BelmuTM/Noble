/*
  Author: Belmu (https://github.com/BelmuTM/)
  */

#version 120

#define SHADOWS 1 // [0 1]

#define SPECULAR 1 // [0 1]
#define SPECULAR_MODE 1 // [0 1]

#define SSAO 1 // [0 1]

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
uniform sampler2D depthtex0;

uniform sampler2D shadowtex0, shadowtex1;
uniform sampler2D shadowcolor0;
uniform sampler2D noisetex;

uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 shadowModelView, shadowProjection;

#include "/lib/Util/distort.glsl"
#include "/lib/Util/noise.glsl"
#include "/lib/Util/math.glsl"
#include "/lib/Util/transforms.glsl"
#include "/lib/Util/util.glsl"
#include "/lib/Lighting/brdf.glsl"
#include "/lib/Lighting/ssao.glsl"
#include "/lib/Lighting/shadows.glsl"
#include "/lib/Lighting/volumetric.glsl"
#include "/lib/Util/color.glsl"

/*
const int colortex0Format = RGBA16F;
const int colortex1Format = RGB16;
const int colortex2Format = RGB16;
*/

const float sunPathRotation = -40.0f;
const int shadowMapResolution = 2048; //[512 1024 2048 3072 4096 7200]
const int noiseTextureResolution = 64;
const float shadowDistanceRenderMul = 1.0f;
const float ambientOcclusionLevel = 0.0f;

const float shininess = 50.0f;

vec3 getDayTimeColor() {
    float wTimeF = float(worldTime);

	  float timeSunrise = ((clamp(wTimeF, 23000.0f, 24000.0f) - 23000.0f) / 1000.0f) + (1.0f - (clamp(wTimeF, 0.0f, 2000.0f) / 2000.0f));
	  float timeNoon = ((clamp(wTimeF, 0.0f, 2000.0f)) / 2000.0f) - ((clamp(wTimeF, 10000.0f, 12000.0f) - 10000.0f) / 2000.0f);
	  float timeSunset = ((clamp(wTimeF, 10000.0f, 12000.0f) - 10000.0f) / 2000.0f) - ((clamp(wTimeF, 12500.0f, 12750.0f) - 12500.0f) / 250.0f);
	  float timeMidnight = ((clamp(wTimeF, 12500.0f, 12750.0f) - 12500.0f) / 250.0f) - ((clamp(wTimeF, 23000.0f, 24000.0f) - 23000.0f) / 1000.0f);

    const vec3 ambient_sunrise = vec3(0.843f, 0.772f, 0.586f) * 0.9f;
    const vec3 ambient_noon = vec3(0.686f, 0.702f, 0.73f) * 0.725f;
    const vec3 ambient_sunset = vec3(0.943f, 0.772f, 0.247f) * 0.26f;
    const vec3 ambient_midnight = vec3(0.06f, 0.088f, 0.117f) * 0.95f;

    return ambient_sunrise * timeSunrise + ambient_noon * timeNoon + ambient_sunset * timeSunset + ambient_midnight * timeMidnight;
}

float adjustLightmapTorch(in float torch) {
    const float K = 2.0f;
    const float P = 5.06f;
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
    vec3 TorchColor = vec3(1.5f, 0.85f, 0.88f);
    vec3 SkyColor = vec3(0.05f, 0.15f, 0.3f);

    vec3 TorchLighting = Lightmap.x * TorchColor;
    vec3 SkyLighting = Lightmap.y * SkyColor;

    return vec3(TorchLighting + SkyLighting);
}

float visibility(in sampler2D ShadowMap, in vec3 SampleCoords) {
    return step(SampleCoords.z - 0.001f, texture2D(ShadowMap, SampleCoords.xy).r);
}

vec3 transparentShadow(in vec3 SampleCoords) {
    float ShadowVisibility0 = visibility(shadowtex0, SampleCoords);
    float ShadowVisibility1 = visibility(shadowtex1, SampleCoords);
    vec4 ShadowColor0 = texture2D(shadowcolor0, SampleCoords.xy);
    vec3 TransmittedColor = ShadowColor0.rgb * (1.0f - ShadowColor0.a);
    return mix((TransmittedColor * 1.2f) * ShadowVisibility1, vec3(1.0f), ShadowVisibility0);
}

#define SHADOW_SAMPLES 3
const int shadowSamplesPerSize = 2 * SHADOW_SAMPLES + 1;
const int totalSamples = shadowSamplesPerSize * shadowSamplesPerSize;

vec3 shadowMap() {
    vec3 viewPos = getViewPos();
    vec4 shadowSpace = viewToShadow(viewPos);
    vec3 sampleCoords = shadowSpace.xyz * 0.5f + 0.5f;

    float randomAngle = texture2D(noisetex, TexCoords * 20.0f).r * 100.0f;
    float cosTheta = cos(randomAngle);
    float sinTheta = sin(randomAngle);
    mat2 rotation =  mat2(cosTheta, -sinTheta, sinTheta, cosTheta) / shadowMapResolution;

    vec3 shadowResult = vec3(0.0f);
    for(int x = -SHADOW_SAMPLES; x <= SHADOW_SAMPLES; x++) {
        for(int y = -SHADOW_SAMPLES; y <= SHADOW_SAMPLES; y++) {

            vec2 offset = rotation * vec2(x, y);
            vec3 currentSampleCoordinate = vec3(sampleCoords.xy + offset, sampleCoords.z);
            shadowResult += transparentShadow(currentSampleCoordinate);
        }
    }
    shadowResult /= totalSamples;
    return shadowResult;
}

void main() {
    vec3 viewPos = getViewPos();
    vec3 viewDir = normalize(-viewPos);
    vec3 Normal = normalize(texture2D(colortex1, TexCoords).rgb * 2.0f - 1.0f);
    vec4 Result = texture2D(colortex0, TexCoords);

    float Depth = texture2D(depthtex0, TexCoords).r;
    if(Depth == 1.0f) {
        gl_FragData[0] = Result;
        return;
    }
    vec3 Albedo = pow(Result.rgb, vec3(2.2f));
    Albedo *= getDayTimeColor();

    vec2 Lightmap = texture2D(colortex2, TexCoords).rg;
    vec3 LightmapColor = getLightmapColor(Lightmap);

    vec3 lightPos = worldTime >= 12750 ? moonPosition : sunPosition;
    vec3 lightDir = normalize(lightPos);
    float NdotL = max(dot(Normal, lightDir), 0.0f);

    vec3 Shadow = vec3(1.0f);
    #if SHADOWS == 1
        Shadow = shadowMap();
    #endif

    vec3 AmbientOcclusion = vec3(1.0f);
    #if SSAO == 1
        AmbientOcclusion = computeSSAO(viewPos, Normal);
    #endif

    vec3 Diffuse = Albedo * (LightmapColor + (NdotL * Shadow));
    vec3 Specular = vec3(0.0f);
    vec3 specColor = specularFresnelSchlick(mix(Albedo, skyColor, 0.5f), NdotL) * Shadow;

    bool isSpecular = isSpecular();
    bool isRaining = rainStrength > 0.0f;
    float rainFactor = 1.0f;
    if(isRaining) rainFactor = rainStrength;

    #if MC_VERSION >= 11300 && SPECULAR == 1
    if(NdotL > 0.0f && !isHandOrEntity()) {
        float specFactor = 0.0f;
        if(isRaining) specFactor = rainStrength;
        specFactor += float(isSpecular);

        #if SPECULAR_MODE == 0
            Specular = phongBRDF(lightDir, viewDir, Normal, specColor, shininess);
        #else
            Specular = blinnPhongBRDF(lightDir, viewDir, Normal, specColor, shininess);
        #endif
        Specular *= clamp(specFactor, 0.0f, 1.0f);
    }
    #endif

    Result = vec4((Diffuse * AmbientOcclusion) + Specular, 1.0f);
    /* DRAWBUFFERS:05 */
    gl_FragData[0] = Result + vec4(computeVolumetric(viewPos), 1.0f);
    gl_FragData[1] = vec4(Albedo, 1.0f);
}
