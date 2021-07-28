/***********************************************/
/*       Copyright (C) Noble RT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec4 qualityBlur(sampler2D tex, vec2 resolution, float size, float quality, float directions) {
    vec4 color = texture2D(tex, texCoords);
    vec2 radius = size / resolution;

    int SAMPLES = 1;
    for(float d = 0.0; d < PI2; d += PI2 / directions) {
		for(float i = 1.0 / quality; i <= 1.0; i += 1.0 / quality) {

			color += texture2D(tex, texCoords + vec2(cos(d), sin(d)) * radius * i);
            SAMPLES++;
        }
    }
    return (color / SAMPLES) / quality * directions;
}

vec4 bilateralBlur(sampler2D tex) {
    vec4 color = texture2D(tex, texCoords);

    int SAMPLES = 1;
    for(int x = -4; x <= 4; x++) {
        for(int y = -4; y <= 4; y++) {
            vec2 offset = vec2(x, y) * pixelSize;
            color += texture2D(tex, texCoords + offset);
            SAMPLES++;
        }
    }
    return color / SAMPLES;
}

// Got help from: https://catlikecoding.com/unity/tutorials/advanced-rendering/depth-of-field/
vec4 bokeh(sampler2D tex, int quality, float radius) {
    vec4 color = texture2D(tex, texCoords);
    vec2 noise = uniformAnimatedNoise();

    int SAMPLES = 1;
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

bool sampleValid(vec2 sampleCoords, vec3 pos, vec3 normal) { 

    bool onScreen = clamp(sampleCoords, vec2(0.0), vec2(1.0)) == sampleCoords;
	vec3 positionAt = vec3(sampleCoords, texture2D(depthtex0, sampleCoords).r);
    positionAt = screenToView(positionAt);
    vec3 normalAt = normalize(decodeNormal(texture2D(colortex1, sampleCoords).xy));

	return   abs(positionAt.x - pos.x) <= EDGE_STOP_THRESHOLD
		&&   abs(positionAt.y - pos.y) <= EDGE_STOP_THRESHOLD
		&&   abs(positionAt.z - pos.z) <= EDGE_STOP_THRESHOLD
        &&  abs(normalAt.x - normal.x) <= EDGE_STOP_THRESHOLD
		&&  abs(normalAt.y - normal.y) <= EDGE_STOP_THRESHOLD
		&&  abs(normalAt.z - normal.z) <= EDGE_STOP_THRESHOLD
		&&  onScreen;
}

vec4 edgeAwareBlur(vec3 viewPos, vec3 normal, sampler2D tex, vec2 resolution, float size, float quality, float directions) {
    vec4 color = texture2D(tex, texCoords);
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
