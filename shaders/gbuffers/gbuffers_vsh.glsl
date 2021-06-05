/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

#define PI 3.14159265358979323846
#define PI2 6.28318530718

#define WATER_WAVE_SPEED 0.7
#define WATER_WAVE_COEF 0.03
#define WATER_WAVE_LENGTH 2.5
#define WATER_WAVE_AMOUNT 5

attribute vec4 at_tangent;
attribute vec4 mc_Entity;

varying vec2 texCoords;
varying vec2 lmCoords;
varying vec4 color;
varying mat3 tbn_matrix;
varying float blockId;
varying vec3 viewPos;

uniform vec3 cameraPosition;
uniform float frameTimeCounter;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;

float signF(float x) {
    if(x == 0.0) return 0.0;
    return x > 0.0 ? 1.0 : -1.0;
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

float rand(vec2 x) {
	return fract(sin(dot(x, vec2(12.9898, 4.1414))) * 43758.5453);
}

float wave(int i, vec2 pos) {
    float randLength = clamp(WATER_WAVE_LENGTH - rand(pos) * i, 0.05, WATER_WAVE_LENGTH);
    float randSpeed = clamp(WATER_WAVE_SPEED - rand(pos) * i, 0.05, WATER_WAVE_SPEED);
    float randCoef = clamp(WATER_WAVE_COEF - rand(pos) * i, 0.05, WATER_WAVE_COEF);

    float frequency = PI2 / randLength;
    float phase = randSpeed * frequency;
    float theta = dot(vec2(rand(pos) * i), pos);
    return randCoef * sin(theta * frequency + frameTimeCounter * phase);
}

float waveHeight(vec2 pos) {
    float height = 0.0;
    for(int i = 0; i < WATER_WAVE_AMOUNT; i++) height += wave(i, pos);
    return height;
}

void main() {
	texCoords = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmCoords = mat2(gl_TextureMatrix[1]) * gl_MultiTexCoord1.st;
    lmCoords = (lmCoords * 33.05 / 32.0) - (1.05 / 32.0);
	
	color = gl_Color;
    vec3 normal = normalize(gl_NormalMatrix * gl_Normal);
	
    viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
    vec4 clipPos = gl_ProjectionMatrix * vec4(viewPos, 1.0);
	
    vec3 tangent = normalize(gl_NormalMatrix * at_tangent.xyz);
    vec3 binormal = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal) * signF(at_tangent.w));
	tbn_matrix = mat3(tangent, binormal, normal);	

	blockId = mc_Entity.x - 1000.0;

    vec4 position = gl_ModelViewMatrix * gl_Vertex;
    position = gbufferModelViewInverse * position;

    /////////////// WAVING WATER ///////////////
    /*
    if(int(blockId) == 6) {
        vec3 cameraPos = cameraPosition + gbufferModelViewInverse[3].xyz;
        vec3 worldPos = position.xyz + cameraPos;
        position.y += waveHeight(worldPos.xz);
    }
    */

    gl_Position = gl_ProjectionMatrix * (gbufferModelView * position);
}
