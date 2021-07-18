/***********************************************/
/*       Copyright (C) Noble SSRT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec4 fastGaussian(sampler2D tex, vec2 resolution, float size, float quality, float directions) {
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
vec4 bokeh(sampler2D tex) {
    vec4 color = vec4(0.0);
    vec2 noise = vec2(bayer64(gl_FragCoord.xy), bayer64(gl_FragCoord.yx));
    noise = fract(frameTimeCounter + noise);

    int SAMPLES;
    for(int i = 0; i < BOKEH_SAMPLES; i++) {
        for(int j = 0; j < BOKEH_SAMPLES; j++) {

            vec2 offset = ((vec2(i, j) + noise) - BOKEH_SAMPLES / 2.0) / BOKEH_SAMPLES;
            if(length(offset) < 0.5) {
                color += texture2D(tex, texCoords + offset * BOKEH_RADIUS / vec2(aspectRatio, 1.0));
                SAMPLES++;
            }
        }
    }
    return color / SAMPLES;
}

#define THRESH 1.41421
bool sampleValid(vec2 sampleCoords, vec3 pos, vec3 normal) { 

    bool onScreen = !any(greaterThan(sampleCoords.xy, vec2(1.0)));
	vec3 positionAt = vec3(sampleCoords, texture2D(depthtex0, sampleCoords).r);
    positionAt = screenToView(positionAt);
	vec3 normalAt = normalize(texture2D(colortex1, sampleCoords).xyz * 2.0 - 1.0);

	return abs(positionAt.z - pos.z) <= THRESH
		&& abs(positionAt.x - pos.x) <= THRESH
		&& abs(positionAt.y - pos.y) <= THRESH
		&& normal == normalAt
		&& onScreen;
}

vec4 edgeStoppingFastGaussian(vec3 viewPos, vec3 normal, sampler2D tex, vec2 resolution, float size, float quality, float directions) {
    vec4 color = vec4(0.0);
    vec2 radius = size / resolution;

    int SAMPLES;
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
