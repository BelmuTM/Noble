/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

#define PI 3.14159265358979323846
#define PI2 6.28318530718

#define WATER_WAVE_SPEED 0.185
#define WATER_WAVE_COEF 0.05
#define WATER_WAVE_LENGTH 2.5
#define WATER_WAVE_AMOUNT 3

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

float wave(int i, vec2 pos) {
    float frequency = PI2 / WATER_WAVE_LENGTH;
    float phase = WATER_WAVE_SPEED * frequency;
    float theta = dot(hash22(vec2(0.5)), pos);
    return WATER_WAVE_COEF * sin(theta * frequency + frameTimeCounter * phase);
}

float waveHeight(vec2 pos) {
    float height = 0.0;
    for(int i = 0; i < WATER_WAVE_AMOUNT; i++) height += wave(i, pos);
    return height;
}

void main() {
	texCoords = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmCoords = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	color = gl_Color;

    vec3 normal = normalize(gl_NormalMatrix * gl_Normal);
    viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
    vec4 clipPos = gl_ProjectionMatrix * vec4(viewPos, 1.0);
	
    vec3 tangent = normalize(gl_NormalMatrix * at_tangent.xyz);
    vec3 binormal = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal) * signF(at_tangent.w));
	tbn_matrix = mat3(tangent, binormal, normal);	

	blockId = mc_Entity.x - 1000.0;
    /*
    vec3 worldPos = (mat3(gbufferModelViewInverse) * (gl_ModelViewMatrix * gl_Vertex).xyz) + (cameraPosition + gbufferModelViewInverse[3].xyz);

    /////////////// WAVING WATER ///////////////
    if(int(blockId) == 6) worldPos.y += waveHeight(worldPos.xz);
    vec3 worldToViewPos = mat3(gbufferModelView) * (worldPos - cameraPosition);
    vec4 viewToClipPos = gl_ProjectionMatrix * vec4(worldToViewPos, 1.0);
    */

    gl_Position = ftransform();
}
