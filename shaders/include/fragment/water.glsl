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
    pos     += (noise(pos) * 2.0 - 1.0);        
    vec2 wv  = 1.0 - abs(sin(pos));
    vec2 swv = abs(cos(pos));    
         wv  = mix(wv, swv, wv);
    return pow(1.0 - pow(wv.x * wv.y, 0.65), steep);
}

float waterWaves(vec2 pos, int octaves) {
    float frequency = WAVE_FREQUENCY;
    float amplitude = WAVE_AMPLITUDE;
    float steepness = WAVE_STEEPNESS;

    float speed = ACCUMULATION_VELOCITY_WEIGHT == 0 ? WAVE_SPEED : 0.0;
    pos.x *= 0.75;
    
    float height = 0.0;    
    for(int i = 0; i < octaves; i++) {        
    	float octave = seaOctave((pos + (frameTimeCounter * speed)) * frequency, steepness)
    	             + seaOctave((pos - (frameTimeCounter * speed)) * frequency, steepness);

        height    += octave * amplitude;        
    	pos       *= mat2(1.6, 1.2, -1.2, 1.6); 
        frequency *= WAVE_LACUNARITY; 
        amplitude *= WAVE_PERSISTANCE;
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

const vec2[2] offset = vec2[2](vec2(1e-1, 0.0), vec2(0.0, 1e-1));

vec3 getWaterNormals(vec3 worldPos, int octaves, float heightFactor) {
    vec2 coords = worldPos.xz - worldPos.y;

    float pos0 = waterWaves(coords,             octaves);
	float pos1 = waterWaves(coords + offset[0], octaves);
	float pos2 = waterWaves(coords + offset[1], octaves);

    return normalize(vec3((pos0 - pos1) * heightFactor, (pos0 - pos2) * heightFactor, 1.0));
}

#if defined STAGE_FRAGMENT
    vec3 getWaterNormalsCheap(vec3 worldPos, int octaves) {
        vec2 coords  = worldPos.xz - worldPos.y;
        float height = waterWaves(coords, octaves);

        vec3 pos = vec3(coords.x, height, coords.y);

        return normalize(cross(dFdx(pos), dFdy(pos)));
    }
#endif
    