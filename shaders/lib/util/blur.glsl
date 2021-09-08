/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
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

const float gaussianWeights[49] = float[49](
0.004696576679070732,
0.005528603997864301,
0.0064630154006652014,
0.007503096437824796,
0.008650306566931922,
0.00990394268015627,
0.011260830280013285,
0.012715060211082848,
0.01425778914891494,
0.01587712131274775,
0.01755808701193398,
0.019282730633218392,
0.0210303165845277,
0.022777656674551675,
0.024499556655159366,
0.026169373490628617,
0.027759668708179853,
0.029242937328683462,
0.03059238678201788,
0.031782736261255995,
0.03279100448992231,
0.03359725310748109,
0.034185253951139895,
0.03454305143322248,
0.03466328834561044,
0.03454305143322248,
0.034185253951139895,
0.03359725310748109,
0.03279100448992231,
0.031782736261255995,
0.03059238678201788,
0.029242937328683462,
0.027759668708179853,
0.026169373490628617,
0.024499556655159366,
0.022777656674551675,
0.0210303165845277,
0.019282730633218392,
0.01755808701193398,
0.01587712131274775,
0.01425778914891494,
0.012715060211082848,
0.011260830280013285,
0.00990394268015627,
0.008650306566931922,
0.007503096437824796,
0.0064630154006652014,
0.005528603997864301,
0.004696576679070732
);

bool edgeStop(vec2 sampleCoords, vec3 pos, vec3 normal) { 
    vec3 positionAt = vec3(sampleCoords, texture2D(depthtex0, sampleCoords).r);
    positionAt = screenToView(positionAt);
    vec3 normalAt = normalize(decodeNormal(texture2D(colortex1, sampleCoords).xy));

    return  abs(positionAt.x - pos.x) <= 0.7
        &&  abs(positionAt.y - pos.y) <= 0.7
        &&  abs(positionAt.z - pos.z) <= 0.7
        &&  abs(normalAt.x - normal.x) <= EDGE_STOP_THRESHOLD
        &&  abs(normalAt.y - normal.y) <= EDGE_STOP_THRESHOLD
        &&  abs(normalAt.z - normal.z) <= EDGE_STOP_THRESHOLD
        &&  clamp(sampleCoords, 0.0, 1.0) == sampleCoords; // Is on screen
}

vec4 gaussianFilter(vec2 coords, vec3 viewPos, vec3 normal, sampler2D tex, vec2 direction) {
    vec4 color = vec4(0.0);
    float totalWeight = 0.0;

    for(int i = 0; i < 49; i++) {
        vec2 sampleCoords = coords + (direction * (i - 24) * pixelSize);
        float weight = gaussianWeights[i] * float(edgeStop(sampleCoords, viewPos, normal));

        color += texture2D(tex, sampleCoords) * weight;
        totalWeight += weight;
    }
    return color / max(EPS, totalWeight);
}

/*
vec4 edgeAwareSpatialDenoiser(vec2 coords, vec3 viewPos, vec3 normal, sampler2D tex, float size, float quality, float directions) {
    vec4 color = texture2D(tex, coords);
    float totalWeight = 1.0;

    for(float d = 0.0; d < PI2; d += PI2 / directions) {
		for(float i = 1.0 / quality; i <= 1.0; i += 1.0 / quality) {
            vec2 sampleCoords = coords + vec2(cos(d), sin(d)) * (size * i * pixelSize);
            float weight = float(edgeStop(sampleCoords, viewPos, normal));

			color += texture2D(tex, sampleCoords) * weight;
            totalWeight += weight;
        } 
    }
    return clamp((color / totalWeight) / quality * directions, 0.0, 1.0);
}
*/
