/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec3 getCausticsViewPos(vec2 coords) {
    vec3 clipPos = vec3(coords, texture(depthtex1, coords).r) * 2.0 - 1.0;
    vec4 tmp = gbufferProjectionInverse * vec4(clipPos, 1.0);
    return tmp.xyz / tmp.w;
}

vec3 waterCaustics(vec2 coords) {
    vec2 worldPos       = viewToWorld(getCausticsViewPos(coords)).xz * 0.5 + 0.5;
    float causticsSpeed = ANIMATED_WATER == 0 ? 0.0 : frameTimeCounter * WATER_CAUSTICS_SPEED;

    vec2 uv0 = (worldPos * (WATER_CAUSTICS_MAX_SIZE - WATER_CAUSTICS_SIZE)) + (causticsSpeed * 0.75);
    vec2 uv1 = (worldPos * ((WATER_CAUSTICS_MAX_SIZE - WATER_CAUSTICS_SIZE) * 0.85)) - causticsSpeed;

    mat3x2 shift = mat3x2(
        vec2( WATER_CAUSTICS_SHIFT, WATER_CAUSTICS_SHIFT),
        vec2( WATER_CAUSTICS_SHIFT,-WATER_CAUSTICS_SHIFT),
        vec2(-WATER_CAUSTICS_SHIFT,-WATER_CAUSTICS_SHIFT)
    );

    vec3 caustics0 = vec3(
        texelFetch(depthtex2, ivec2(uv0 + shift[0]) & causticsRes, 0).r,
        texelFetch(depthtex2, ivec2(uv0 + shift[1]) & causticsRes, 0).g,
        texelFetch(depthtex2, ivec2(uv0 + shift[2]) & causticsRes, 0).b
    );

    vec3 caustics1 = vec3(
        texelFetch(shadowcolor1, ivec2(uv1 + shift[0]) & causticsRes, 0).r,
        texelFetch(shadowcolor1, ivec2(uv1 + shift[1]) & causticsRes, 0).g,
        texelFetch(shadowcolor1, ivec2(uv1 + shift[2]) & causticsRes, 0).b
    );

    return min(caustics0, caustics1) * WATER_CAUSTICS_STRENGTH;
}

float waterFoam(float dist) {
    if(dist < FOAM_FALLOFF_DISTANCE * FOAM_EDGE_FALLOFF) {
        float falloff = (dist / FOAM_FALLOFF_DISTANCE) + FOAM_FALLOFF_BIAS;
        float leading = dist / (FOAM_FALLOFF_DISTANCE * FOAM_EDGE_FALLOFF);
        
	    return falloff * (1.0 - leading);
    }
    return 0.0;
}

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

	vec2 waveDir = -sincos(windRad);
    float waves = 0.0;

    float noise;
    noise          = FBM(coords * 0.02 / sqrt(waveLength) - (speed * waveDir), 1);
    waves         += -gerstnerWaves(coords + vec2(noise, -noise) * sqrt(waveLength), speed, waveSteepness, waveAmplitude, waveLength, waveDir);
    waveSteepness *= 1.0;
    waveAmplitude *= 0.6;
    waveLength    *= 1.8;
    waveDir        = -sincos(windRad + 0.9);

    noise          = FBM(coords * 0.03 / sqrt(waveLength) - (speed * waveDir), 2);
    waves         += -gerstnerWaves(coords + vec2(-noise, noise) * sqrt(waveLength), speed, waveSteepness, waveAmplitude, waveLength, waveDir);
    waveSteepness *= 1.0;
    waveAmplitude *= 0.6;
    waveLength    *= 0.7;
    waveDir        = sincos(windRad - 1.8);

    noise          = FBM(coords * 0.01 / sqrt(waveLength) - (speed * waveDir), 3);
    waves         += -gerstnerWaves(coords + vec2(-noise) * sqrt(waveLength), speed, waveSteepness, waveAmplitude, waveLength, waveDir);
    waveSteepness *= 1.0;
    waveAmplitude *= 2.6;
    waveLength    *= 0.8;
    waveDir        = sincos(windRad + 2.7);

    noise          = FBM(coords * 0.01 / sqrt(waveLength) - (speed * waveDir), 4);
    waves         += -gerstnerWaves(coords + vec2(noise) * sqrt(waveLength), speed, waveSteepness, waveAmplitude, waveLength, waveDir);
    waveSteepness *= 1.3;
    waveAmplitude *= 0.3;
    waveLength    *= 0.4;
    waveDir        = sincos(windRad - 3.6);

    noise          = FBM(coords * 0.03 / sqrt(waveLength) - (speed * waveDir), 5);
    waves         += -gerstnerWaves(coords + vec2(-noise, noise) * sqrt(waveLength), speed, waveSteepness, waveAmplitude, waveLength, waveDir);
    waveSteepness *= 1.5;
    waveAmplitude *= 0.4;
    waveLength    *= 0.6;
    waveDir        = sincos(windRad - 0.4);

    noise          = FBM(coords * 2.3 / sqrt(waveLength) - (speed * waveDir), 6);
    waves         += -gerstnerWaves(coords + vec2(noise, -noise) * sqrt(waveLength), speed, waveSteepness, waveAmplitude, waveLength, waveDir);
	return waves;
}

vec3 getWaveNormals(vec3 worldPos) {
    vec2 coords = worldPos.xz - worldPos.y;

    const float delta = 1e-1;
    float normal0 = computeWaves(coords);
	float normal1 = computeWaves(coords + vec2(delta, 0.0));
	float normal2 = computeWaves(coords + vec2(0.0, delta));

    return normalize(vec3(
        (normal0 - normal1) / delta,
        (normal0 - normal2) / delta,
        1.0
    ));
}
    