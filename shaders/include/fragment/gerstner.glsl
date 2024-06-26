/***********************************************/
/*          Copyright (C) 2024 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

float gerstnerWaves(vec2 coords, float time, float steepness, float amplitude, float lambda, vec2 direction) {
    const float g = 9.81; // Earth's gravity constant

	float k = TAU / lambda;
    float x = (sqrt(g * k)) * time - k * dot(direction, coords);

    return amplitude * pow(sin(x) * 0.5 + 0.5, steepness);
}

float calculateWaveHeightGerstner(vec2 position, int octaves) {
    float height = 0.0;

    float speed     = 0.8;
    float time      = RENDER_MODE == 0 ? frameTimeCounter * speed : 1.0;
    float steepness = WAVE_STEEPNESS;
    float amplitude = WAVE_AMPLITUDE;
    float lambda    = WAVE_LENGTH;

    const float angle   = 2.6;
	const mat2 rotation = mat2(cos(angle), -sin(angle), sin(angle), cos(angle));

    vec2 direction = vec2(0.786, 0.352);

    for(int i = 0; i < octaves; i++) {
        float noise = FBM(position * inversesqrt(lambda) - (speed * direction), 1, 0.7);

        height += gerstnerWaves(position + vec2(noise, -noise) * sqrt(lambda), time, steepness, amplitude, lambda, direction) - noise * amplitude;

        steepness *= 1.02;
        amplitude *= 0.90;
        lambda    *= 0.89;
        direction *= rotation;
    }
    return height;
}

const vec2 offset = vec2(0.015, 0.0);

vec3 getWaterNormals(vec3 worldPosition, int octaves) {
    vec2 position = worldPosition.xz;

    float pos0 = calculateWaveHeightGerstner(position,             octaves);
	float pos1 = calculateWaveHeightGerstner(position + offset.xy, octaves);
	float pos2 = calculateWaveHeightGerstner(position + offset.yx, octaves);

    return vec3(pos0 - pos1, pos0 - pos2, 1.0);
}
