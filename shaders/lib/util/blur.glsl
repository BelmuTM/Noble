/***********************************************/
/*       Copyright (C) Noble RT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec4 qualityBlur(vec2 coords, sampler2D tex, vec2 resolution, float size, float quality, float directions) {
    vec4 color = texture2D(tex, coords);
    vec2 radius = size / resolution;

    int SAMPLES = 1;
    for(float d = 0.0; d < PI2; d += PI2 / directions) {
		for(float i = 1.0 / quality; i <= 1.0; i += 1.0 / quality) {

			color += texture2D(tex, coords + vec2(cos(d), sin(d)) * radius * i);
            SAMPLES++;
        }
    }
    return (color / SAMPLES) / quality * directions;
}

vec4 bilateralBlur(vec2 coords, sampler2D tex, int size) {
    vec4 color = texture2D(tex, coords);

    int SAMPLES = 1;
    for(int x = -size; x <= size; x++) {
        for(int y = -size; y <= size; y++) {
            vec2 offset = vec2(x, y) * pixelSize;
            color += texture2D(tex, coords + offset);
            SAMPLES++;
        }
    }
    return color / SAMPLES;
}

vec4 bokeh(vec2 coords, sampler2D tex, vec2 resolution, int quality, float radius) {
    vec4 color = texture2D(tex, coords);
    vec2 noise = uniformAnimatedNoise();

    int SAMPLES = 1;
    for(int i = 0; i < quality; i++) {
        for(int j = 0; j < quality; j++) {
            vec2 offset = ((vec2(i, j) + noise) - quality * 0.5) / quality;
            
            if(length(offset) < 0.5) {
                color += texture2D(tex, coords + ((offset * radius) * resolution));
                SAMPLES++;
            }
        }
    }
    return color / SAMPLES;
}

vec4 radialBlur(vec2 coords, sampler2D tex, vec2 resolution, int quality, float size) {
    vec4 color = texture2D(tex, texCoords);
    vec2 radius = size / resolution;

    int SAMPLES = 1;
    for(int i = 0; i < quality; i++){
        float d = (i * PI2) / quality;
        vec2 sampleCoords = coords + vec2(sin(d), cos(d)) * radius;
            
        color += texture2D(tex, sampleCoords);
        SAMPLES++;
    }
    return clamp(color / SAMPLES, 0.0, 1.0);
}

const float gaussianWeights[33] = float[33](
    0.004013,
    0.005554,
    0.007527,
    0.00999,
    0.012984,
    0.016524,
    0.020594,
    0.025133,
    0.030036,
    0.035151,
    0.040283,
    0.045207,
    0.049681,
    0.053463,
    0.056341,
    0.058141,
    0.058754,
    0.058141,
    0.056341,
    0.053463,
    0.049681,
    0.045207,
    0.040283,
    0.035151,
    0.030036,
    0.025133,
    0.020594,
    0.016524,
    0.012984,
    0.00999,
    0.007527,
    0.005554,
    0.004013
);

bool sampleValid(vec2 sampleCoords, vec3 pos, vec3 normal) { 
	vec3 posAt = vec3(sampleCoords, texture2D(depthtex0, sampleCoords).r);
    posAt = screenToView(posAt);

	return abs(dot(posAt - pos, normal)) <= EDGE_STOP_THRESHOLD
    && clamp(sampleCoords, 0.0, 1.0) == sampleCoords; // Is on screen
}

vec4 gaussianFilter(vec2 coords, vec3 worldPos, vec3 normal, sampler2D tex, vec2 direction, float radius) {
    vec4 color = vec4(0.0);
    float totalWeight = 0.0;

    for(int i = 0; i < 33; i++) {
        vec2 sampleCoords = coords + (direction * (i - 16) * pixelSize);
        float kernelWeight = gaussianWeights[i];

        vec3 posAt = vec3(sampleCoords, texture2D(depthtex0, sampleCoords).r);
        posAt = viewToWorld(screenToView(posAt));

        float posWeight = 1.0 / max(distance(posAt, worldPos), EDGE_STOP_THRESHOLD);
        posWeight = pow(posWeight, 12.0);

        vec3 normalAt = normalize(decodeNormal(texture2D(colortex1, sampleCoords).xy));
        float normalWeight = max(pow(max(dot(normal, normalAt), 0.0), 12.0), EDGE_STOP_THRESHOLD);
        float weight = kernelWeight * clamp(normalWeight * posWeight, 0.0, 1.0);
        
        color += texture2D(tex, sampleCoords) * weight;
        totalWeight += weight;
    }
    return color / max(EPS, totalWeight);
}

vec4 spatialDenoiser(vec2 coords, vec3 viewPos, vec3 normal, sampler2D tex, float size, float quality, float directions) {
    vec4 color = texture2D(tex, coords);
    float totalWeight = 1.0;

    for(float d = 0.0; d < PI2; d += PI2 / directions) {
		for(float i = 1.0 / quality; i <= 1.0; i += 1.0 / quality) {
            vec2 sampleCoords = coords + vec2(cos(d), sin(d)) * (size * i * pixelSize);
            float weight = float(sampleValid(sampleCoords, viewPos, normal));

			color += texture2D(tex, sampleCoords) * weight;
            totalWeight += weight;
        } 
    }
    return clamp((color / totalWeight) / quality * directions, 0.0, 1.0);
}
