/***********************************************/
/*       Copyright (C) Noble SSRT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec4 qualityBlur(sampler2D tex, vec2 resolution, float size, float quality, float directions) {
    vec4 color = vec4(0.0);
    vec2 radius = size / resolution;

    int SAMPLES;
    for(float d = 0.0; d < PI2; d += PI2 / directions) {
		for(float i = 1.0 / quality; i <= 1.0; i += 1.0 / quality) {

			color += texture2D(tex, texCoords + vec2(cos(d), sin(d)) * radius * i);
            SAMPLES++;
        }
    }
    return (color / SAMPLES) / quality * directions;
}

vec4 bilateralBlur(sampler2D tex) {
    vec4 color = vec4(0.0);

    int SAMPLES;
    for(int x = -4 ; x <= 4; x++) {
        for(int y = -4; y <= 4; y++) {
            vec2 offset = vec2(y, x) * pixelSize;
            color += texture2D(tex, texCoords + offset);
            SAMPLES++;
        }
    }
    return color / SAMPLES;
}

// Got help from: https://catlikecoding.com/unity/tutorials/advanced-rendering/depth-of-field/
vec4 bokeh(sampler2D tex, int quality, float radius) {
    vec4 color = vec4(0.0);
    vec2 noise = texture2D(noisetex, texCoords * 5.0).xy;
    noise.x = mod(noise.x + GOLDEN_RATIO * frameTimeCounter, 1.0);
    noise.y = mod(noise.y + (GOLDEN_RATIO * 2.0) * mod(frameTimeCounter, 100.0), 1.0);

    int SAMPLES;
    for(int i = 0; i < quality; i++) {
        for(int j = 0; j < quality; j++) {
            vec2 offset = ((vec2(i, j) + noise) - quality * 0.5) / quality;
            
            if(length(offset) < 0.5) {
                color += texture2D(tex, texCoords + offset * radius / aspectRatio);
                SAMPLES++;
            }
        }
    }
    return color / SAMPLES;
}

#define THRESH 1.41421
bool sampleValid(vec2 sampleCoords, vec3 pos) { 

    bool onScreen = !any(greaterThan(sampleCoords.xy, vec2(1.0)));
	vec3 positionAt = vec3(sampleCoords, texture2D(depthtex0, sampleCoords).r);
    positionAt = screenToView(positionAt);

	return abs(positionAt.z - pos.z) <= THRESH
		&& abs(positionAt.x - pos.x) <= THRESH
		&& abs(positionAt.y - pos.y) <= THRESH
		&& onScreen;
}

vec4 edgeStoppingBlur(vec3 viewPos, sampler2D tex, vec2 resolution, float size, float quality, float directions) {
    vec4 color = vec4(0.0);
    vec2 radius = size / resolution;

    int SAMPLES;
    for(float d = 0.0; d < PI2; d += PI2 / directions) {
		for(float i = 1.0 / quality; i <= 1.0; i += 1.0 / quality) {
            vec2 sampleCoords = texCoords + vec2(cos(d), sin(d)) * radius * i;

            if(sampleValid(sampleCoords, viewPos)) {
			    color += texture2D(tex, sampleCoords);
                SAMPLES++;
            }
        }
    }
    return clamp((color / SAMPLES) / quality * directions, 0.0, 1.0);
}

vec4 radialBlur(sampler2D tex, vec2 resolution, int quality, float size) {
    vec4 color = texture2D(tex, texCoords);
    vec2 radius = size / resolution;

    int SAMPLES = 1;
    for(int i = 0; i < quality; i++){
        float d = (i * PI2) / quality;
        vec2 sampleCoords = texCoords + vec2(sin(d), cos(d)) * radius;
            
        color += texture2D(tex, sampleCoords);
        SAMPLES++;
    }
    return clamp(color / SAMPLES, 0.0, 1.0);
}

vec4 edgeAwareRadialBlur(vec3 viewPos, sampler2D tex, vec2 resolution, int quality, float size) {
    vec4 color = texture2D(tex, texCoords);
    vec2 radius = size / resolution;

    int SAMPLES = 1;
    for(int i = 0; i < quality; i++){
        float d = (i * PI2) / quality;
        vec2 sampleCoords = texCoords + vec2(sin(d), cos(d)) * radius;
            
        if(sampleValid(sampleCoords, viewPos)) {
            color += texture2D(tex, sampleCoords);
            SAMPLES++;
        }
    }
    return clamp(color / SAMPLES, 0.0, 1.0);
}
