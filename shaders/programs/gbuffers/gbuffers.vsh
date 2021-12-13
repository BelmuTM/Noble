/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

attribute vec4 at_tangent;
attribute vec3 mc_Entity;

out vec2 texCoords;
out vec2 lmCoords;
out vec3 waterNormals;
out vec4 color;
out mat3 TBN;
out float blockId;

#include "/settings.glsl"
#define STAGE STAGE_VERTEX

#include "/include/uniforms.glsl"
#include "/include/utility/noise.glsl"
#include "/include/utility/math.glsl"
#include "/include/utility/transforms.glsl"
#include "/include/fragment/water.glsl"

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

vec2 taaJitter(vec4 pos) {
    return taaOffsets[framemod] * (pos.w * pixelSize);
}

void main() {
	texCoords = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmCoords  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	color     = gl_Color;

    vec3 normal  = normalize(gl_NormalMatrix * gl_Normal);
    vec3 viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;

    vec3 tangent   = normalize(gl_NormalMatrix * at_tangent.xyz);
    vec3 bitangent = normalize(cross(tangent, normal) * sign(at_tangent.w));
	TBN 		   = mat3(tangent, bitangent, normal);

	blockId = mc_Entity.x - 1000.0;
	gl_Position = ftransform();

	#ifdef WATER
		if(int(blockId + 0.5) == 1) {
			vec3 worldPos = viewToWorld(viewPos);
			worldPos.y   += computeWaves(worldPos.xz);
			waterNormals  = getWaveNormals(worldPos);

    		vec4 viewToClip = gl_ProjectionMatrix * vec4(worldToView(worldPos), 1.0);
			gl_Position    += viewToClip;
		}
	#endif

	#if TAA == 1
		bool canJitter = ACCUMULATION_VELOCITY_WEIGHT == 0 ? true : hasMoved();
		if(canJitter) { gl_Position.xy += taaJitter(gl_Position); }
    #endif
}
