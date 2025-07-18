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

/*
    [References]:
        ajgryc. (2013). Improvements to the canonical one-liner GLSL rand() for OpenGL ES 2.0. http://byteblacksmith.com/improvements-to-the-canonical-one-liner-glsl-rand-for-opengl-es-2-0/
        O'Neill, M. (2018). PCG, A Family of Better Random Number Generators. https://www.pcg-random.org/
    [Notes]:
        Functions that generate pseudo-random numbers with various distribution techniques.
*/

// Jodie's dithering
float bayer2(vec2 a) {
    a = floor(a);
    return fract(dot(a, vec2(0.5, a.y * 0.75)));
}

#define bayer4(a)   (bayer2(0.5   * (a))  *  0.25 + bayer2(a))
#define bayer8(a)   (bayer4(0.5   * (a))  *  0.25 + bayer2(a))
#define bayer16(a)  (bayer8(0.5   * (a))  *  0.25 + bayer2(a))
#define bayer32(a)  (bayer16(0.5  * (a))  *  0.25 + bayer2(a))
#define bayer64(a)  (bayer32(0.5  * (a))  *  0.25 + bayer2(a))
#define bayer128(a) (bayer64(0.5  * (a))  *  0.25 + bayer2(a))
#define bayer256(a) (bayer128(0.5 * (a))  *  0.25 + bayer2(a))
#define bayer512(a) (bayer256(0.5 * (a))  *  0.25 + bayer2(a))

#if defined STAGE_FRAGMENT

    void pcg(inout uint seed) {
        uint state = seed * 747796405u + 2891336453u;
        uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
        seed = (word >> 22u) ^ word;
    }

    uint rngState = uint(viewWidth * viewHeight) * uint(frameCounter) + ((uint(gl_FragCoord.x) << 16u) ^ uint(gl_FragCoord.y * viewWidth));
    
    float randF()  { pcg(rngState); return float(rngState) / float(0xffffffffu); }
    vec2  rand2F() { return vec2(randF(), randF());                              }

#endif

float temporalBlueNoise(vec2 uv) {
    return fract(texelFetch(noisetex, ivec2(uv) % noiseTextureResolution, 0).rgb + GOLDEN_RATIO * frameCounter).r;
}

float interleavedGradientNoise(vec2 uv) {
    uv += float(frameCounter) * 5.588238;
    return fract(52.9829189 * fract(0.06711056 * uv.x + 0.00583715 * uv.y));  
}

float rand(vec2 uv) {
    float dt = dot(uv.xy, vec2(12.9898, 78.233));
    return fract(sin(mod(dt, PI)) * 43758.5453);
}

float hash12(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float hash13(vec3 p) {
    p  = fract(p * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}

float noise(vec2 uv) {
    vec2 ip = floor(uv);
    vec2 u  = fract(uv);
    u = u * u * (3.0 - 2.0 * u);

    float res = mix(
        mix(hash12(ip), hash12(ip + vec2(1.0, 0.0)), u.x),
        mix(hash12(ip + vec2(0.0, 1.0)), hash12(ip + vec2(1.0, 1.0)), u.x), u.y);
    return res * res;
}

float noise(vec3 pos) {
    vec3 i = floor(pos);
    vec3 f = fract(pos);
    vec3 u = f * f * (3.0 - 2.0 * f);

    return mix(mix(mix(hash13(i + vec3(0.0, 0.0, 0.0)), hash13(i + vec3(1.0, 0.0, 0.0)), u.x),
                   mix(hash13(i + vec3(0.0, 1.0, 0.0)), hash13(i + vec3(1.0, 1.0, 0.0)), u.x), u.y),
               mix(mix(hash13(i + vec3(0.0, 0.0, 1.0)), hash13(i + vec3(1.0, 0.0, 1.0)), u.x),
                   mix(hash13(i + vec3(0.0, 1.0, 1.0)), hash13(i + vec3(1.0, 1.0, 1.0)), u.x), u.y), u.z);
}

const float fbmLacunarity  = 2.0;
const float fbmPersistance = 0.5;

float FBM(vec2 uv, int octaves, float frequency) {
    float height    = 0.0;
    float amplitude = 1.0;

    for (int i = 0; i < octaves; i++) {
        height    += noise(uv * frequency) * amplitude;
        frequency *= fbmLacunarity;
        amplitude *= fbmPersistance;
    }
    return height;
}

float FBM(vec3 pos, int octaves, float frequency) {
    float height    = 0.0;
    float amplitude = 1.0;

    for (int i = 0; i < octaves; i++) {
        height    += noise(pos * frequency) * amplitude;
        frequency *= fbmLacunarity;
        amplitude *= fbmPersistance;
    }
    return height;
}
