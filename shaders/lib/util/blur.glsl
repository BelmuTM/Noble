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
    0.0000051697,
    0.0000173053,
    0.0000535861,
    0.0001534900,
    0.0004066886,
    0.0009967720,
    0.0022598456,
    0.0047392326,
    0.0091935037,
    0.0164966617,
    0.0273811989,
    0.0420388718,
    0.0597026841,
    0.0784301322,
    0.0953056177,
    0.1071268647,
    0.1113847490,
    0.1071268647,
    0.0953056177,
    0.0784301322,
    0.0597026841,
    0.0420388718,
    0.0273811989,
    0.0164966617,
    0.0091935037,
    0.0047392326,
    0.0022598456,
    0.0009967720,
    0.0004066886,
    0.0001534900,
    0.0000535861,
    0.0000173053,
    0.0000051697
);

bool sampleValid(vec2 sampleCoords, vec3 pos, vec3 normal) { 
    
	vec3 positionAt = vec3(sampleCoords, texture2D(depthtex0, sampleCoords).r);
    positionAt = screenToView(positionAt);
    vec3 normalAt = normalize(decodeNormal(texture2D(colortex1, sampleCoords).xy));

	return   abs(positionAt.x - pos.x) <= EDGE_STOP_THRESHOLD
		&&   abs(positionAt.y - pos.y) <= EDGE_STOP_THRESHOLD
		&&   abs(positionAt.z - pos.z) <= EDGE_STOP_THRESHOLD
        &&  abs(normalAt.x - normal.x) <= EDGE_STOP_THRESHOLD
		&&  abs(normalAt.y - normal.y) <= EDGE_STOP_THRESHOLD
		&&  abs(normalAt.z - normal.z) <= EDGE_STOP_THRESHOLD
		&&  clamp(sampleCoords, 0.0, 1.0) == sampleCoords; // Is on screen
}

vec4 gaussianFilter(vec3 viewPos, vec3 normal, sampler2D tex, float radius) {
    vec4 color = vec4(0.0);
    float totalWeight = 0.0;

    for(int i = 0; i < 32; i++) {
        float weight = gaussianWeights[i];
        vec2 sampleCoords = texCoords + (poisson128[i] * radius * pixelSize);
        float edge = float(sampleValid(sampleCoords, viewPos, normal));

        color += (texture2D(tex, sampleCoords) * weight) * edge;
        totalWeight += edge;
    }
    return color / max(EPS, totalWeight);
}

vec4 spatialDenoiser(float scale, vec3 viewPos, vec3 normal, sampler2D tex, vec2 resolution, float size, float quality, float directions) {
    vec4 color = vec4(0.0);
    vec2 radius = size / resolution;

    int SAMPLES = 1;
    for(float d = 0.0; d < PI2; d += PI2 / directions) {
		for(float i = 1.0 / quality; i <= 1.0; i += 1.0 / quality) {
            vec2 sampleCoords = texCoords + vec2(cos(d), sin(d)) * radius * i;
            
            if(sampleValid(sampleCoords, viewPos, normal)) {
			    color += texture2D(tex, sampleCoords);
                SAMPLES++;
            }
        }
    }
    return clamp((color / SAMPLES) / quality * directions, 0.0, 1.0);
}
