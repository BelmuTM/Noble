/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

attribute vec4 at_tangent;

varying vec2 texCoords;
varying vec2 lmCoords;
varying vec4 color;
varying mat3 tbn_matrix;

float signF(float x) {
    if(x == 0.0) return 0.0;
    return x > 0.0 ? 1.0 : -1.0;
}

void main() {
	gl_Position = ftransform();
	texCoords = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmCoords = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	color = gl_Color;

    vec3 normal = normalize(gl_NormalMatrix * gl_Normal);
	
    vec3 tangent = normalize(gl_NormalMatrix * at_tangent.xyz);
    vec3 binormal = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal) * signF(at_tangent.w));
	tbn_matrix = mat3(tangent, binormal, normal);	  
}
