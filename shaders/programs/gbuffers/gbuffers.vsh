/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#define attribute in
attribute vec4 at_tangent;
attribute vec3 mc_Entity;
attribute vec2 mc_midTexCoord;

flat out int blockId;
out vec2 texCoords;
out vec2 lmCoords;
out vec3 viewPos;
out vec3 geoNormal;
out vec4 vertexColor;
out mat3 TBN;

#define STAGE_VERTEX

#include "/settings.glsl"
#include "/include/uniforms.glsl"

#include "/include/utility/rng.glsl"
#include "/include/utility/math.glsl"
#include "/include/utility/transforms.glsl"
#include "/include/utility/color.glsl"

#include "/include/vertex/animation.glsl"

void main() {
	texCoords   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmCoords    = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	vertexColor = gl_Color;

	#ifndef PROGRAM_BASIC 
    	geoNormal = mat3(gbufferModelViewInverse) * (gl_NormalMatrix * gl_Normal);
    	viewPos   = transMAD(gl_ModelViewMatrix, gl_Vertex.xyz);

    	vec3 tangent = mat3(gbufferModelViewInverse) * (gl_NormalMatrix * (at_tangent.xyz / at_tangent.w));
		TBN 		 = mat3(tangent, cross(tangent, geoNormal), geoNormal);
	#endif

	blockId 	  = int((mc_Entity.x - 1000.0) + 0.25);
	vec3 worldPos = transMAD(gbufferModelViewInverse, viewPos);

	#if ACCUMULATION_VELOCITY_WEIGHT == 0
		#ifdef PROGRAM_TERRAIN
			animate(worldPos, texCoords.y < mc_midTexCoord.y);
		#endif

		#ifdef PROGRAM_WEATHER
			worldPos.xz += RAIN_DIRECTION * worldPos.y;
		#endif
	#endif
	
	gl_Position = transMAD(gbufferModelView, worldPos).xyzz * diag4(gl_ProjectionMatrix) + gl_ProjectionMatrix[3];

	#ifdef PROGRAM_ENTITY
		// Thanks Niemand#1929 for the nametag fix
		if(vertexColor.a >= 0.24 && vertexColor.a < 0.255) {
			gl_Position = vec4(10.0, 10.0, 10.0, 1.0);
		}
	#endif

	#if TAA == 1
		gl_Position.xy += taaJitter(gl_Position);
    #endif
}
