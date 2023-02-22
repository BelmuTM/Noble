/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/*
    const bool colortex4MipmapEnabled = true;
*/

// Maximum values for x amount of bits and their inverses (2^x - 1)
const float maxVal8     = 255.0;
const float maxVal16    = 65535.0;
const float rcpMaxVal8  = 0.00392156;
const float rcpMaxVal12 = 0.00024420;
const float rcpMaxVal13 = 0.00012208;
const float rcpMaxVal16 = 0.00001525;

#include "/settings.glsl"
#include "/include/uniforms.glsl"

#include "/include/utility/rng.glsl"
#include "/include/utility/math.glsl"
#include "/include/utility/color.glsl"

#include "/include/atmospherics/constants.glsl"

#include "/include/utility/transforms.glsl"
#include "/include/utility/phase.glsl"

#include "/include/material.glsl"

//////////////////////////////////////////////////////////
/*-------------- MISC UTILITY FUNCTIONS ----------------*/
//////////////////////////////////////////////////////////

const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
float tmp = fract(worldTime / 24000.0 - 0.25);
float ang = (tmp + (cos(tmp * 3.14159265358979) * -0.5 + 0.5 - tmp) / 3.0) * 6.28318530717959;

vec3 sunPosNorm = vec3(-sin(ang), cos(ang) * sunRotationData);

bool isSky(vec2 coords)  { return texture(depthtex0, coords).r == 1.0;                          }
bool isHand(vec2 coords) { return linearizeDepth(texture(depthtex0, coords).r) < MC_HAND_DEPTH; }

const vec2 hiZOffsets[] = vec2[](
	vec2(0.0, 0.0 ),
	vec2(0.5, 0.0 ),
    vec2(0.5, 0.25)
);

float find2x2MinimumDepth(vec2 coords, int scale) {
    coords *= viewSize;

    return minOf(vec4(
        texelFetch(depthtex0, ivec2(coords)                      , 0).r,
        texelFetch(depthtex0, ivec2(coords) + ivec2(1, 0) * scale, 0).r,
        texelFetch(depthtex0, ivec2(coords) + ivec2(0, 1) * scale, 0).r,
        texelFetch(depthtex0, ivec2(coords) + ivec2(1, 1) * scale, 0).r
    ));
}

//////////////////////////////////////////////////////////
/*----------------- TEXTURE SAMPLING -------------------*/
//////////////////////////////////////////////////////////

/*
    Bicubic texture filtering
    SOURCE: provided by swr#1793
*/
vec4 cubic(float v) {
    vec4 n  = vec4(1.0, 2.0, 3.0, 4.0) - v;
    vec4 s  = pow3(n);
    float x = s.x;
    float y = s.y - 4.0 * s.x;
    float z = s.z - 4.0 * s.y + 6.0 * s.x;
    float w = 6.0 - x - y - z;
    return vec4(x, y, z, w) * rcp(6.0);
}
 
vec4 textureBicubic(sampler2D tex, vec2 texCoords) {
    vec2 texSize    = textureSize(tex, 0);
    vec2 invTexSize = 1.0 / texSize;
 
    texCoords = texCoords * texSize - 0.5;
 
    vec2 fxy   = fract(texCoords);
    texCoords -= fxy;
 
    vec4 xcubic = cubic(fxy.x);
    vec4 ycubic = cubic(fxy.y);
 
    vec4 c = texCoords.xxyy + vec2(-0.5, 1.5).xyxy;
 
    vec4 s      = vec4(xcubic.xz + xcubic.yw, ycubic.xz + ycubic.yw);
    vec4 offset = c + vec4(xcubic.yw, ycubic.yw) / s;
 
    offset *= invTexSize.xxyy;
 
    vec4 sample0 = texture(tex, offset.xz);
    vec4 sample1 = texture(tex, offset.yz);
    vec4 sample2 = texture(tex, offset.xw);
    vec4 sample3 = texture(tex, offset.yw);
 
    float sx = s.x / (s.x + s.y);
    float sy = s.z / (s.z + s.w);
 
    return mix(mix(sample3, sample2, sx), mix(sample1, sample0, sx), sy);
}

/*
    Texture CatmullRom taken from TheRealMJP (https://github.com/TheRealMJP)
    SOURCE: https://gist.github.com/TheRealMJP/c83b8c0f46b63f3a88a5986f4fa982b1
*/

// Samples a texture with Catmull-Rom filtering, using 9 texture fetches instead of 16.
// See http://vec3.ca/bicubic-filtering-in-fewer-taps/ for more details
vec4 textureCatmullRom(in sampler2D tex, in vec2 coords) {
    vec2 texSize    = textureSize(tex, 0);
    vec2 rcpTexSize = 1.0 / texSize;

    vec2 samplePos = coords * texSize;
    vec2 texPos1   = floor(samplePos - 0.5) + 0.5;

    vec2 f = samplePos - texPos1;

    vec2 w0 = f * (-0.5 + f * (1.0 - 0.5 * f));
    vec2 w1 = 1.0 + f * f * (-2.5 + 1.5 * f);
    vec2 w2 = f * (0.5 + f * (2.0 - 1.5 * f));
    vec2 w3 = f * f * (-0.5 + 0.5 * f);

    vec2 w12      = w1 + w2;
    vec2 offset12 = w2 / (w1 + w2);

    vec2 texPos0  = texPos1 - 1.0;
    vec2 texPos3  = texPos1 + 2.0;
    vec2 texPos12 = texPos1 + offset12;

    texPos0  *= rcpTexSize;
    texPos3  *= rcpTexSize;
    texPos12 *= rcpTexSize;

    vec4 result = vec4(0.0);
    result += texture(tex, vec2(texPos0.x, texPos0.y),  0.0) * w0.x  * w0.y;
    result += texture(tex, vec2(texPos12.x, texPos0.y), 0.0) * w12.x * w0.y;
    result += texture(tex, vec2(texPos3.x, texPos0.y),  0.0) * w3.x  * w0.y;

    result += texture(tex, vec2(texPos0.x, texPos12.y),  0.0) * w0.x  * w12.y;
    result += texture(tex, vec2(texPos12.x, texPos12.y), 0.0) * w12.x * w12.y;
    result += texture(tex, vec2(texPos3.x, texPos12.y),  0.0) * w3.x  * w12.y;

    result += texture(tex, vec2(texPos0.x, texPos3.y),  0.0) * w0.x  * w3.y;
    result += texture(tex, vec2(texPos12.x, texPos3.y), 0.0) * w12.x * w3.y;
    result += texture(tex, vec2(texPos3.x, texPos3.y),  0.0) * w3.x  * w3.y;
    return result;
}

/*
    Linear texture sampling methods provided by null511#3026 (https://github.com/null511)
    SOURCE: https://github.com/null511/MC-Arc-Shader/blob/main/shaders/lib/sampling/linear.glsl
*/
vec2 getLinearCoords(const in vec2 coords, const in vec2 texSize, out vec2 uv[4]) {
    vec2 f         = fract(coords * texSize);
    vec2 pixelSize = rcp(texSize);

    uv[0] = coords - f * pixelSize;
    uv[1] = uv[0] + vec2(1.0, 0.0) * pixelSize;
    uv[2] = uv[0] + vec2(0.0, 1.0) * pixelSize;
    uv[3] = uv[0] + vec2(1.0, 1.0) * pixelSize;
    return f;
}

float linearBlend4(const in vec4 samples, const in vec2 f) {
    float x1 = mix(samples[0], samples[1], f.x);
    float x2 = mix(samples[2], samples[3], f.x);
    return mix(x1, x2, f.y);
}

vec3 linearBlend4(const in vec3 samples[4], const in vec2 f) {
    vec3 x1 = mix(samples[0], samples[1], f.x);
    vec3 x2 = mix(samples[2], samples[3], f.x);
    return mix(x1, x2, f.y);
}

vec3 textureLodLinearRGB(const in sampler2D samplerName, const in vec2 uv[4], const in int lod, const in vec2 f) {
    vec3 samples[4];
    samples[0] = textureLod(samplerName, uv[0], lod).rgb;
    samples[1] = textureLod(samplerName, uv[1], lod).rgb;
    samples[2] = textureLod(samplerName, uv[2], lod).rgb;
    samples[3] = textureLod(samplerName, uv[3], lod).rgb;
    return linearBlend4(samples, f);
}

vec3 textureLodLinearRGB(const in sampler2D samplerName, const in vec2 coords, const in vec2 texSize, const in int lod) {
    vec2 uv[4];
    vec2 f = getLinearCoords(coords, texSize, uv);
    return textureLodLinearRGB(samplerName, uv, lod, f);
}

float textureGradLinear(const in sampler2D samplerName, const in vec2 uv[4], const in mat2 dFdXY, const in vec2 f, const in int comp) {
    vec4 samples;
    samples[0] = textureGrad(samplerName, uv[0], dFdXY[0], dFdXY[1])[comp];
    samples[1] = textureGrad(samplerName, uv[1], dFdXY[0], dFdXY[1])[comp];
    samples[2] = textureGrad(samplerName, uv[2], dFdXY[0], dFdXY[1])[comp];
    samples[3] = textureGrad(samplerName, uv[3], dFdXY[0], dFdXY[1])[comp];
    return linearBlend4(samples, f);
}

float textureGradLinear(const in sampler2D samplerName, const in vec2 coords, const in vec2 texSize, const in mat2 dFdXY, const in int comp) {
    vec2 uv[4];
    vec2 f = getLinearCoords(coords, texSize, uv);
    return textureGradLinear(samplerName, uv, dFdXY, f, comp);
}
