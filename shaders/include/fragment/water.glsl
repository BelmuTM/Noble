/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/*
#if defined STAGE_FRAGMENT
    vec3 waterCaustics(vec2 coords) {
        vec2 worldPos       = viewToWorld(getViewPos1(coords)).xz * 0.5 + 0.5;
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
#endif
*/

/*
    CREDITS:
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
    float freq  = 0.16;
    float amp   = WAVE_AMPLITUDE;
    float steep = WAVE_STEEPNESS;
    float speed = GI == 0 ? WAVE_SPEED : 0.0;
    pos.x *= 0.75;
    
    float d, height = 0.0;    
    for(int i = 0; i < octaves; i++) {        
    	d  = seaOctave((pos + (frameTimeCounter * speed)) * freq, steep);
    	d += seaOctave((pos - (frameTimeCounter * speed)) * freq, steep);

        height += d * amp;        
    	pos   *= mat2(1.6, 1.2, -1.2, 1.6); freq *= 1.9; amp *= 0.22;
        steep = mix(steep, 1.0, 0.2);
    }
    return height;
}

/*
OLD WAVES

float calculateWaterWaves(vec2 coords) {
	float speed         = ANIMATED_WATER == 1 ? frameTimeCounter * WAVE_SPEED : 0.0;
    float waveSteepness = WAVE_STEEPNESS, waveAmplitude = WAVE_AMPLITUDE, waveLength = WAVE_LENGTH;
	vec2 waveDir        = -sincos(0.078);

    const float waveAngle = 2.4;
	const mat2 rotation   = mat2(cos(waveAngle), -sin(waveAngle), sin(waveAngle), cos(waveAngle));

    float waves = 0.0;
    for(int i = 0; i < WAVE_OCTAVES; i++) {
        float noise    = FBM(coords * inversesqrt(waveLength) - (speed * waveDir), 3);
        waves         += -gerstnerWaves(coords + vec2(noise, -noise) * sqrt(waveLength), speed, waveSteepness, waveAmplitude, waveLength, waveDir) - noise * waveAmplitude;
        waveSteepness *= 1.4;
        waveAmplitude *= 0.7;
        waveLength    *= 0.9;
        waveDir       *= rotation;
    }
    return waves;
}

float gerstnerWaves(vec2 coords, float time, float waveSteepness, float waveAmplitude, float waveLength, vec2 waveDir) {
	float k = TAU / waveLength;
    float x = (sqrt(9.81 * k)) * time - k * dot(waveDir, coords);

    return waveAmplitude * pow(sin(x) * 0.5 + 0.5, waveSteepness);
}
*/

vec3 getWaveNormals(vec3 worldPos, int octaves) {
    vec2 coords = worldPos.xz - worldPos.y;

    const float delta = 1e-1;
    float normal0 = waterWaves(coords,                    octaves);
	float normal1 = waterWaves(coords + vec2(delta, 0.0), octaves);
	float normal2 = waterWaves(coords + vec2(0.0, delta), octaves);

    return normalize(vec3(
        (normal0 - normal1) / delta,
        (normal0 - normal2) / delta,
        1.0
    ));
}
    