/*
  Author: Belmu (https://github.com/BelmuTM/)
  */

#version 120

#define SHADOWS 1 // [0 1]
#define shadowMapResolution 2048 // [512 1024 2048 3072 4096 7200]
#define SPECULAR 1 // [0 1]
#define SPECULAR_MODE 1 // [0 1]
#define SSR 1 // [0 1]
#define SSAO 0 // [0 1]

varying vec2 TexCoords;
varying vec2 LightmapCoords;

uniform vec3 sunPosition, moonPosition, cameraPosition, skyColor;
uniform float viewWidth, viewHeight, rainStrength, near, far, aspectRatio, frameTimeCounter;
uniform int isEyeInWater, worldTime, moonPhase;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D depthtex0;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform sampler2D noisetex;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

#include "/lib/Util/distort.glsl"
#include "/lib/Util/math.glsl"
#include "/lib/Util/transforms.glsl"
#include "/lib/Util/util.glsl"
#include "/lib/Util/intersect.glsl"
#include "/lib/Lighting/brdf.glsl"
#include "/lib/Lighting/ssao.glsl"
#include "/lib/Lighting/raytracer.glsl"
#include "/lib/Util/color.glsl"

/*
const int colortex0Format = RGBA16F;
const int colortex1Format = RGB16;
const int colortex2Format = RGB16;
*/

const float sunPathRotation = -40.0f;
const int noiseTextureResolution = 64;
const float shadowDistanceRenderMul = 1.0f;
const float ambientOcclusionLevel = 0.0f;

const float shininess = 52.5f;

vec3 getDayTimeColor() {
    float wTimeF = float(worldTime);

	  float timeSunrise = ((clamp(wTimeF, 23000.0f, 24000.0f) - 23000.0f) / 1000.0f) + (1.0f - (clamp(wTimeF, 0.0f, 2000.0f) / 2000.0f));
	  float timeNoon = ((clamp(wTimeF, 0.0f, 2000.0f)) / 2000.0f) - ((clamp(wTimeF, 10000.0f, 12000.0f) - 10000.0f) / 2000.0f);
	  float timeSunset = ((clamp(wTimeF, 10000.0f, 12000.0f) - 10000.0f) / 2000.0f) - ((clamp(wTimeF, 12500.0f, 12750.0f) - 12500.0f) / 250.0f);
	  float timeMidnight = ((clamp(wTimeF, 12500.0f, 12750.0f) - 12500.0f) / 250.0f) - ((clamp(wTimeF, 23000.0f, 24000.0f) - 23000.0f) / 1000.0f);

    const vec3 ambient_sunrise = vec3(0.543f, 0.772f, 0.786f);
    const vec3 ambient_noon = vec3(0.686f, 0.702f, 0.73f);
    const vec3 ambient_sunset = vec3(0.543f, 0.772f, 0.747f);
    const vec3 ambient_midnight = vec3(0.06f, 0.088f, 0.117f);

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

#define SHADOW_SAMPLES 2
const int ShadowSamplesPerSize = 2 * SHADOW_SAMPLES + 1;
const int TotalSamples = ShadowSamplesPerSize * ShadowSamplesPerSize;

vec3 shadowMap() {
    vec3 viewPos = getViewPos();

    vec4 World = gbufferModelViewInverse * vec4(viewPos, 1.0f);
    vec4 ShadowSpace = shadowProjection * shadowModelView * World;
    ShadowSpace.xy = distortPosition(ShadowSpace.xy);
    vec3 SampleCoords = ShadowSpace.xyz * 0.5f + 0.5f;

    float randomAngle = texture2D(noisetex, TexCoords * 20.0f).r * 100.0f;
    float cosTheta = cos(randomAngle);
	  float sinTheta = sin(randomAngle);
    mat2 rotation =  mat2(cosTheta, -sinTheta, sinTheta, cosTheta) / shadowMapResolution;

    vec3 ShadowResult = vec3(0.0f);
    for(int x = -SHADOW_SAMPLES; x <= SHADOW_SAMPLES; x++) {
        for(int y = -SHADOW_SAMPLES; y <= SHADOW_SAMPLES; y++) {

            vec2 Offset = rotation * vec2(x, y);
            vec3 CurrentSampleCoordinate = vec3(SampleCoords.xy + Offset, SampleCoords.z);
            ShadowResult += transparentShadow(CurrentSampleCoordinate);
        }
    }
    ShadowResult /= TotalSamples;
    return ShadowResult;
}

void main() {
    vec3 viewPos = getViewPos();
    vec3 viewDir = normalize(-viewPos);
    float blockId = getBlockId(colortex5);

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
    vec3 LightmapColor = getLightmapColor(Lightmap) * 3.0f;
    vec3 lightPos = worldTime >= 12750 ? moonPosition : sunPosition;
    vec3 lightDir = normalize(lightPos);

    float NdotL = max(dot(Normal, lightDir), 0.0f);
    vec3 Shadow = vec3(1.0f);

    if(SHADOWS == 1) Shadow = shadowMap(); // rayTraceShadows(lightDir, viewPos, Normal);

    vec3 Diffuse = Albedo * (LightmapColor + (NdotL * Shadow));
    vec3 Specular = vec3(0.0f);
    vec3 specColor = mix(blendOverlay(Albedo, vec3(1.0f), 5.0f), skyColor, 0.15f) * Shadow;

    bool isSpecular = true;
    bool isRaining = rainStrength > 0.0f;
    float rainFactor = 1.0f;
    if(isRaining) rainFactor = rainStrength;

    #if MC_VERSION >= 11300
    if(SPECULAR == 1 && NdotL > 0.0f && !isHandOrEntity()) {
        float specFactor = 0.0f;
        if(isRaining) specFactor = rainStrength;
        specFactor += float(isSpecular);

        if(SPECULAR_MODE == 0)
            Specular = phongBRDF(lightDir, viewDir, Normal, specColor, shininess);
        else if(SPECULAR_MODE == 1)
            Specular = blinnPhongBRDF(lightDir, viewDir, Normal, specColor, shininess);

        Specular *= clamp(specFactor, 0.0f, 1.0f);
    }
    #endif

    vec3 AmbientOcclusion = vec3(1.0f);
    if(SSAO == 1) AmbientOcclusion = computeSSAO(viewPos, Normal);

    Result = vec4((Diffuse * AmbientOcclusion) + Specular, 1.0f);

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = Result;
}
