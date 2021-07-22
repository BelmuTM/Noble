/***********************************************/
/*       Copyright (C) Noble RT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/settings.glsl"

attribute vec4 at_tangent;
attribute vec3 mc_Entity;

varying vec2 texCoords;
varying vec2 lmCoords;
varying vec4 color;
varying mat3 TBN;
varying float blockId;
varying vec3 viewPos;

void main() {
	texCoords = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmCoords = mat2(gl_TextureMatrix[1]) * gl_MultiTexCoord1.st;
    lmCoords = (lmCoords * 33.05 / 32.0) - (1.05 / 32.0);
	
	color = gl_Color;
    vec3 normal = normalize(gl_NormalMatrix * gl_Normal);
	
    viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
    vec4 clipPos = gl_ProjectionMatrix * vec4(viewPos, 1.0);
	
    vec3 tangent = normalize(gl_NormalMatrix * at_tangent.xyz);
    vec3 binormal = normalize(cross(tangent, normal) * sign(at_tangent.w));
	TBN = mat3(tangent, binormal, normal);	

	blockId = mc_Entity.x - 1000.0;
    gl_Position = ftransform();
}
