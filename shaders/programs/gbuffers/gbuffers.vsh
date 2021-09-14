/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

attribute vec4 at_tangent;
attribute vec3 mc_Entity;

varying vec2 texCoords;
varying vec2 lmCoords;
varying vec4 color;
varying mat3 TBN;
varying float blockId;
varying vec3 heightNormal;

#include "/settings.glsl"
#include "/lib/uniforms.glsl"

vec2 taaOffsets[8] = vec2[8](
	vec2( 0.125,-0.375),
	vec2(-0.125, 0.375),
	vec2( 0.625, 0.125),
	vec2( 0.375,-0.625),
	vec2(-0.625, 0.625),
	vec2(-0.875,-0.125),
	vec2( 0.375,-0.875),
	vec2( 0.875, 0.875)
);

uniform int framemod;
vec2 taaJitter(vec4 pos) {
    return taaOffsets[framemod] * (pos.w * pixelSize);
}

const float amplitude = 0.07;
const float waveAmount = 0.8;
const float yOffset = 0.2;

float waterHeight(vec2 pos) {
	float wave0 = (amplitude * sin(pos.x + (frameTimeCounter * 2.0)) / waveAmount) - yOffset;
	float wave1 = (amplitude * cos(pos.y + (frameTimeCounter)) / waveAmount) - yOffset;
	return wave0 + wave1;
}

// https://wiki.shaderlabs.org/wiki/Shader_tricks#From_heightmaps
vec3 normalFromHeight(vec2 pos, float stepSize) {
    vec2 e = vec2(stepSize, 0);
    vec3 px1 = vec3(pos.x - e.x, waterHeight(pos - e.xy), pos.y - e.y);
    vec3 px2 = vec3(pos.x + e.x, waterHeight(pos + e.xy), pos.y + e.y);
    vec3 py1 = vec3(pos.x - e.y, waterHeight(pos - e.yx), pos.y - e.x);
    vec3 py2 = vec3(pos.x + e.y, waterHeight(pos + e.yx), pos.y + e.x);
    
    return normalize(cross(px2 - px1, py2 - py1));
}

void main() {
	texCoords = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmCoords = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	color = gl_Color;

    vec3 normal = normalize(gl_NormalMatrix * gl_Normal);
    vec3 viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
    vec4 clipPos = gl_ProjectionMatrix * vec4(viewPos, 1.0);

	blockId = mc_Entity.x - 1000.0;
	gl_Position = ftransform();

	#ifdef WATER
		if(int(blockId + 0.5) == 1) {
			vec3 worldPos = (mat3(gbufferModelViewInverse) * viewPos) + (cameraPosition + gbufferModelViewInverse[3].xyz);
			worldPos.y += waterHeight(worldPos.xz);
			normal = normalize(mat3(gbufferModelView) * normalFromHeight(worldPos.xz, EPS));

			vec3 worldToView = mat3(gbufferModelView) * (worldPos - cameraPosition);
    		vec4 viewToClip = gl_ProjectionMatrix * vec4(worldToView, 1.0);
			gl_Position += viewToClip;
		}
	#endif

	vec3 tangent = normalize(gl_NormalMatrix * at_tangent.xyz);
    vec3 binormal = normalize(cross(tangent, normal) * sign(at_tangent.w));
	TBN = mat3(tangent, binormal, normal);	

    #if TAA == 1
        gl_Position.xy += taaJitter(gl_Position);
    #endif
}
