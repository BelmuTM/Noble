/********************************************************************************/
/*                                                                              */
/*    Noble Shaders                                                             */
/*    Copyright (C) 2026  Belmu                                                 */
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

#define WAVE_GERSTNER_SETUP()                                                    \
    float speed      = WAVE_SPEED;                                               \
    float steepness  = WAVE_STEEPNESS;                                           \
    float amplitude  = WAVE_AMPLITUDE;                                           \
    float wavelength = WAVE_LENGTH * 4.5;                                        \
                                                                                 \
    float time = RENDER_MODE == 0 ? frameTimeCounter * speed : 1.0;              \
                                                                                 \
    const float angle   = radians(WAVE_ANGLE);                                   \
    const mat2 rotation = mat2(cos(angle), -sin(angle), sin(angle), cos(angle)); \
                                                                                 \
    vec2 direction = vec2(0.1, 0.1);                                             \
                                                                                 \
    float noise = texture(noisetex, position * 1e-2).a;                          \

#define WAVE_GERSTNER_PARAMS_FACTOR()        \
    steepness  *= WAVE_STEEPNESS_MULTIPLIER; \
    amplitude  *= WAVE_AMPLITUDE_MULTIPLIER; \
    wavelength *= WAVE_LENGTH_MULTIPLIER;    \
    direction  *= rotation;             

const float g = 9.81; // Earth's gravitational constant

float gerstnerWaves(vec2 coords, float time, float steepness, float amplitude, float lambda, vec2 direction) {
    direction = normalize(direction);

    float k = TAU / lambda;
    float x = fastSqrtN1(g * k) * time - k * dot(direction, coords);

    return amplitude * pow(sin(x) * 0.5 + 0.5, steepness);
}

vec2 gerstnerWavesDerivative(vec2 coords, float time, float steepness, float amplitude, float lambda, vec2 direction) {
    direction = normalize(direction);

    float k = TAU / lambda;
    float x = fastSqrtN1(g * k) * time - k * dot(direction, coords);

    float u    = sin(x) * 0.5 + 0.5;
    float dudx = -0.5 * cos(x) * k;

    return amplitude * steepness * pow(u, steepness - 1.0) * dudx * direction;
}

float calculateWaveHeightGerstner(vec2 position, int octaves) {
    float height = 0.0;

    WAVE_GERSTNER_SETUP();

    float totalAmplitude = EPS;

    for (int i = 0; i < octaves; i++) {

        height += gerstnerWaves(
            position,
            time + noise * 2.0,
            steepness,
            amplitude,
            wavelength,
            direction
        );

        WAVE_GERSTNER_PARAMS_FACTOR();

        totalAmplitude += amplitude;
    }

    return height / totalAmplitude;
}

vec2 calculateWaveDerivativeGerstner(vec2 position, int octaves) {
    vec2 derivative = vec2(0.0);

    WAVE_GERSTNER_SETUP();

    for (int i = 0; i < octaves; i++) {

        derivative += gerstnerWavesDerivative(
            position,
            time + noise * 2.0,
            steepness,
            amplitude,
            wavelength,
            direction
        );

        WAVE_GERSTNER_PARAMS_FACTOR();
    }

    return derivative;
}

vec3 getWaterNormal(vec3 worldPosition, vec3 worldNormal, int octaves, float strength) {
    vec2 waveDerivative = calculateWaveDerivativeGerstner(worldPosition.xz, octaves) * strength;

    return normalize(
        rotate(
            normalize(vec3(-waveDerivative.x, 1.0, -waveDerivative.y)),
            vec3(0.0, 1.0, 0.0),
            worldNormal
        )
    );
}

vec3 getWaterNormal(vec3 worldPosition, vec3 worldNormal, int octaves) {
    return getWaterNormal(worldPosition, worldNormal, octaves, WATER_NORMALS_STRENGTH * WATER_NORMALS_STRENGTH_MULTIPLIER);
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

