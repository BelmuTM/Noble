/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/*
    SOURCE:
    Water waves algorithm from: https://www.shadertoy.com/view/Ms2SD1
*/

float seaOctave(vec2 pos, float steep) {
    pos     += (-1.0 + 2.0 * noise(pos));        
    vec2 wv  = 1.0 - abs(sin(pos));
    vec2 swv = abs(cos(pos));    
         wv  = mix(wv, swv, wv);
    return pow(1.0 - pow(wv.x * wv.y, 0.65), steep);
}

float waterWaves(vec2 pos, int octaves) {
    float frequency         = 0.16;
    float amplitude         = WAVE_AMPLITUDE;
    float steepness         = WAVE_STEEPNESS;
    const float lacunarity  = 1.9;
    const float persistance = 0.22;

    float speed = ACCUMULATION_VELOCITY_WEIGHT == 0 ? WAVE_SPEED : 0.0;
    pos.x *= 0.75;
    
    float height = 0.0;    
    for(int i = 0; i < octaves; i++) {        
    	float octave = seaOctave((pos + (frameTimeCounter * speed)) * frequency, steepness)
    	             + seaOctave((pos - (frameTimeCounter * speed)) * frequency, steepness);

        height    += octave * amplitude;        
    	pos       *= mat2(1.6, 1.2, -1.2, 1.6); 
        frequency *= lacunarity; 
        amplitude *= persistance;
        steepness  = mix(steepness, 1.0, 0.2);
    }
    return height;
}

/*
float gerstnerWaves(vec2 coords, float time, float waveSteepness, float waveAmplitude, float waveLength, vec2 waveDir) {
	float k = TAU / waveLength;
    float x = (sqrt(9.81 * k)) * time - k * dot(waveDir, coords);

    return waveAmplitude * pow(sin(x) * 0.5 + 0.5, waveSteepness);
}

float calculateWaterWaves(vec2 coords, int octaves) {
	float speed         = ANIMATED_WATER == 1 ? frameTimeCounter * 1.0 : 0.0;
    float waveSteepness = WAVE_STEEPNESS, waveAmplitude = WAVE_AMPLITUDE, waveLength = 5.0;
	vec2 waveDir        = -sincos(0.078);

    const float waveAngle = 1.4;
	const mat2 rotation   = mat2(cos(waveAngle), -sin(waveAngle), sin(waveAngle), cos(waveAngle));

    float waves = 0.0;
    for(int i = 0; i < octaves; i++) {
        float noise    = FBM(coords * inversesqrt(waveLength) - (speed * waveDir), 3);
        waves         += -gerstnerWaves(coords + vec2(noise, -noise) * sqrt(waveLength), speed, waveSteepness, waveAmplitude, waveLength, waveDir) - noise * waveAmplitude;
        waveSteepness *= 1.2;
        waveAmplitude *= 0.7;
        waveLength    *= 0.7;
        waveDir       *= rotation;
    }
    return waves;
}
*/

vec3 getWaterNormals(vec3 worldPos, int octaves) {
    vec2 coords = worldPos.xz - worldPos.y;

    const float delta = 1e-1;
    float normal0 = waterWaves(coords,                    octaves);
	float normal1 = waterWaves(coords + vec2(delta, 0.0), octaves);
	float normal2 = waterWaves(coords + vec2(0.0, delta), octaves);

    return normalize(vec3(
        (normal0 - normal1) * rcp(delta),
        (normal0 - normal2) * rcp(delta),
        1.0
    ));
}
    