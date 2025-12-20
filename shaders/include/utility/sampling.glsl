/********************************************************************************/
/*                                                                              */
/*    Noble Shaders                                                             */
/*    Copyright (C) 2025  Belmu                                                 */
/*                                                                              */
/*    This program is free software: you can redistribute it and/or modify      */
/*    it under the terms of the GNU General Public License as published by      */
/*    the Free Software Foundation, either version 3 of the License, or         */
/*    (at your option) any later version.                                       */
/*                                                                              */
/*    This program is distributed in the hope that it will be useful,           */
/*    but WITHOUT ANY WARRANTY; without even the implied warranty of            */
/*    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the             */
/*    GNU General Public License for more details.                              */
/*                                                                              */
/*    You should have received a copy of the GNU General Public License         */
/*    along with this program.  If not, see <https://www.gnu.org/licenses/>.    */
/*                                                                              */
/********************************************************************************/

vec4 cubicWeight(float v) {
    vec4 s = pow3(vec4(1.0, 2.0, 3.0, 4.0) - v);
    vec4 weight;
         weight.x = s.x;
         weight.y = s.y - 4.0 * s.x;
         weight.z = s.z - 4.0 * s.y + 6.0 * s.x;
         weight.w = 6.0 - weight.x - weight.y - weight.z;
    return weight / 6.0;
}
 
vec4 textureBicubic(sampler2D tex, vec2 coords) {
    vec2 texSize    = textureSize(tex, 0);
    vec2 invTexSize = 1.0 / texSize;
 
    coords = coords * texSize - 0.5;
 
    vec2 fxy = fract(coords);

    coords -= fxy;
 
    vec4 xcubic = cubicWeight(fxy.x);
    vec4 ycubic = cubicWeight(fxy.y);
 
    vec4 c      = coords.xxyy + vec2(-0.5, 1.5).xyxy;
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

// https://iquilezles.org/articles/texture/
vec4 textureCubic(sampler2D tex, vec2 coords) {
    coords = coords * viewSize + 0.5;
    vec2 fcoords = fract(coords);
    coords = floor(coords) + fcoords * fcoords * (3.0 - 2.0 * fcoords);
    coords = (coords - 0.5) * texelSize;
    return texture(tex, coords);
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
    result += texture(tex, vec2(texPos0.x , texPos0.y)) * w0.x  * w0.y;
    result += texture(tex, vec2(texPos12.x, texPos0.y)) * w12.x * w0.y;
    result += texture(tex, vec2(texPos3.x , texPos0.y)) * w3.x  * w0.y;

    result += texture(tex, vec2(texPos0.x , texPos12.y)) * w0.x  * w12.y;
    result += texture(tex, vec2(texPos12.x, texPos12.y)) * w12.x * w12.y;
    result += texture(tex, vec2(texPos3.x , texPos12.y)) * w3.x  * w12.y;

    result += texture(tex, vec2(texPos0.x , texPos3.y)) * w0.x  * w3.y;
    result += texture(tex, vec2(texPos12.x, texPos3.y)) * w12.x * w3.y;
    result += texture(tex, vec2(texPos3.x , texPos3.y)) * w3.x  * w3.y;
    return result;
}

/*
    Linear texture sampling methods provided by null511#3026 (https://github.com/null511)
    SOURCE: https://github.com/null511/MC-Arc-Shader/blob/main/shaders/lib/sampling/linear.glsl
*/
vec2 getLinearCoords(const in vec2 coords, const in vec2 texSize, out vec2 uv[4]) {
    vec2 f         = fract(coords * texSize);
    vec2 texelSize = rcp(texSize);

    uv[0] = coords - f * texelSize;
    uv[1] = uv[0] + vec2(1.0, 0.0) * texelSize;
    uv[2] = uv[0] + vec2(0.0, 1.0) * texelSize;
    uv[3] = uv[0] + vec2(1.0, 1.0) * texelSize;
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