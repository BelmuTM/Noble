/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

float gerstnerWaves(vec2 coords, float time, float waveSteepness, float waveAmplitude, float waveLength, vec2 waveDir) {
	float k = TAU / waveLength;
    float w = sqrt(9.81 * k);

    float x = w * time - k * dot(waveDir, coords);
    return waveAmplitude * pow(sin(x) * 0.5 + 0.5, waveSteepness);
}

const float windRad = 0.785398;

float computeWaves(vec2 coords) {
	float speed = ANIMATED_WATER == 1 ? frameTimeCounter * WAVE_SPEED : 0.0;

    float waveSteepness = WAVE_STEEPNESS;
	float waveAmplitude = WAVE_AMPLITUDE;
	float waveLength    = WAVE_LENGTH;

	vec2 waveDir = -sincos2(windRad);
    float waves = 0.0;

    vec2 noiseMovement = speed * waveDir; vec2 noise;
    noise          = voronoise(coords * 0.02 / sqrt(waveLength) - noiseMovement, 1.0, 0.0);
    waves         += -gerstnerWaves(coords + noise * sqrt(waveLength), speed, waveSteepness, waveAmplitude, waveLength, waveDir);
    waveSteepness *= 1.0;
    waveAmplitude *= 0.6;
    waveLength    *= 1.8;
    waveDir  = sincos2(windRad + 0.9);

    noise          = voronoise(coords * 0.03 / sqrt(waveLength) - noiseMovement, 0.0, 0.0);
    waves         += -gerstnerWaves(coords + noise * sqrt(waveLength), speed, waveSteepness, waveAmplitude, waveLength, waveDir);
    waveSteepness *= 1.0;
    waveAmplitude *= 0.6;
    waveLength    *= 0.7;
    waveDir  = sincos2(windRad - 1.8);

    noise          = voronoise(coords * 0.01 / sqrt(waveLength) - noiseMovement, 0.0, 1.0);
    waves         += -gerstnerWaves(coords + noise * sqrt(waveLength), speed, waveSteepness, waveAmplitude, waveLength, waveDir);
    waveSteepness *= 1.0;
    waveAmplitude *= 2.6;
    waveLength    *= 0.8;
    waveDir  = sincos2(windRad + 2.7);

    noise          = voronoise(coords * 0.01 / sqrt(waveLength) - noiseMovement, 1.0, 1.0);
    waves         += -gerstnerWaves(coords + noise * sqrt(waveLength), speed, waveSteepness, waveAmplitude, waveLength, waveDir);
    waveSteepness *= 1.3;
    waveAmplitude *= 0.3;
    waveLength    *= 0.4;
    waveDir  = sincos2(windRad - 3.6);

    noise          = voronoise(coords * 0.03 / sqrt(waveLength) - noiseMovement, 0.0, 1.0);
    waves         += -gerstnerWaves(coords + noise * sqrt(waveLength), speed, waveSteepness, waveAmplitude, waveLength, waveDir);
    waveSteepness *= 1.5;
    waveAmplitude *= 0.4;
    waveLength    *= 0.6;
    waveDir  = sincos2(windRad - 0.4);

    noise          = voronoise(coords * 2.3 / sqrt(waveLength) - noiseMovement, 0.0, 1.0);
    waves         += -gerstnerWaves(coords + noise * sqrt(waveLength), speed, waveSteepness, waveAmplitude, waveLength, waveDir);
	return waves;
}

vec3 getWaveNormals(vec3 worldPos) {
    vec2 coords = worldPos.xz - worldPos.y;

    const float delta = 1e-1;
    float normal0 = computeWaves(coords);
	float normal1 = computeWaves(coords + vec2(delta, 0.0));
	float normal2 = computeWaves(coords + vec2(0.0, delta));

    vec3 n;
	n.x = (normal0 - normal1) / delta;
    n.y = (normal0 - normal2) / delta;
    n.z = 1.0;

    return normalize(n);
}
    