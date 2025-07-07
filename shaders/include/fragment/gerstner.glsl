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

const float g = 9.81; // Earth's gravitational constant

float gerstnerWaves(vec2 coords, float time, float steepness, float amplitude, float lambda, vec2 direction) {
    float k = TAU / lambda;
    float x = fastSqrtN1(g * k) * time - k * dot(direction, coords);

    return amplitude * pow(sin(x) * 0.5 + 0.5, steepness);
}

float calculateWaveHeightGerstner(vec2 position, int octaves) {
    float height = 0.0;

    float speed     = 0.8;
    float time      = RENDER_MODE == 0 ? frameTimeCounter * speed : 1.0;
    float steepness = WAVE_STEEPNESS;
    float amplitude = WAVE_AMPLITUDE;
    float lambda    = WAVE_LENGTH;

    const float angle   = radians(155.0);
    const mat2 rotation = mat2(cos(angle), -sin(angle), sin(angle), cos(angle));

    vec2 direction = vec2(0.2, 0.3);

    for (int i = 0; i < octaves; i++) {
        float noise = FBM(position * fastInvSqrtN1(lambda) - (speed * direction), 2, 1.0);

        height += gerstnerWaves(position + vec2(noise, -noise) * fastSqrtN1(lambda), time, steepness, amplitude, lambda, direction) - noise * amplitude;

        steepness *= 1.05;
        amplitude *= 0.90;
        lambda    *= 0.85;
        direction *= rotation;
    }
    return height;
}

const vec2 offset = vec2(0.015, 0.0);

vec3 getWaterNormals(vec3 worldPosition, int octaves) {
    float pos0 = calculateWaveHeightGerstner(worldPosition.xz,             octaves);
    float pos1 = calculateWaveHeightGerstner(worldPosition.xz + offset.xy, octaves);
    float pos2 = calculateWaveHeightGerstner(worldPosition.xz + offset.yx, octaves);

    return vec3(pos0 - pos1, pos0 - pos2, 1.0);
}

vec3 getWaterNormals(vec3 worldPosition, float strength, int octaves) {
    const float dStep = offset.x;

    vec2 steps;
    steps.x = calculateWaveHeightGerstner(worldPosition.xz + vec2( dStep, -dStep), octaves);
    steps.y = calculateWaveHeightGerstner(worldPosition.xz + vec2(-dStep,  dStep), octaves);
    steps  -= calculateWaveHeightGerstner(worldPosition.xz + vec2(-dStep, -dStep), octaves);
    steps  *= strength;

    return normalize(vec3(-steps.x, dStep * 2.0, -steps.y));
}

vec2 parallaxMappingWater(vec2 coords, vec3 tangentDirection, int octaves) {
    const float layerHeight = 1.0 / WATER_PARALLAX_LAYERS;

    vec2 increment = tangentDirection.xy / tangentDirection.z * WATER_PARALLAX_DEPTH * layerHeight;

    float currHeight = calculateWaveHeightGerstner(coords, octaves);
    float prevHeight;
    
    float traceDistance = 0.0;

    for (int i = 0; i < WATER_PARALLAX_LAYERS && traceDistance < currHeight; i++) {
        coords        -= increment;
        prevHeight     = currHeight;
        currHeight     = calculateWaveHeightGerstner(coords, octaves);
        traceDistance += layerHeight;
    }

    vec2 prevCoords = coords + increment;
    
    float beforeHeight = prevHeight - traceDistance + layerHeight;
    float afterHeight  = currHeight - traceDistance;
    float weight       = afterHeight / (afterHeight - beforeHeight);

    return mix(coords, prevCoords, weight);
}
