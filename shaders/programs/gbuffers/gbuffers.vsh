/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#define attribute in
attribute vec4 at_tangent;
attribute vec3 mc_Entity;
attribute vec2 mc_midTexCoord;

flat out int blockId;
out vec2 texCoords;
out vec2 lmCoords;
out vec2 texSize;
out vec2 botLeft;
out vec3 viewPos;
out vec4 vertexColor;
out mat3 TBN;

#define STAGE_VERTEX

#include "/include/common.glsl"
#include "/include/vertex/animation.glsl"

void main() {
	#if defined PROGRAM_HAND && DISCARD_HAND == 1
		gl_Position = vec4(1.0);
		return;
	#endif

	texCoords   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmCoords    = gl_MultiTexCoord1.xy * rcp(240.0);
	vertexColor = gl_Color;

	#if POM > 0 && defined PROGRAM_TERRAIN
		vec2 halfSize = abs(texCoords - mc_midTexCoord);
		texSize       = halfSize * 2.0;
		botLeft       = mc_midTexCoord - halfSize;
	#endif

	#ifndef PROGRAM_BASIC 
    	vec3 geoNormal = mat3(gbufferModelViewInverse) * (gl_NormalMatrix * gl_Normal);
    		 viewPos   = transform(gl_ModelViewMatrix, gl_Vertex.xyz);

    	vec3 tangent = mat3(gbufferModelViewInverse) * (gl_NormalMatrix * (at_tangent.xyz / at_tangent.w));
		TBN			 = mat3(tangent, cross(tangent, geoNormal), geoNormal);
	#endif

	blockId 	  = int((mc_Entity.x - 1000.0) + 0.25);
	vec3 worldPos = transform(gbufferModelViewInverse, viewPos);

	#if RENDER_MODE == 0
		#ifdef PROGRAM_TERRAIN
			animate(worldPos, texCoords.y < mc_midTexCoord.y);
		#endif

		#ifdef PROGRAM_WEATHER
			worldPos.xz += RAIN_DIRECTION * worldPos.y;
		#endif
	#endif
	
	gl_Position = transform(gbufferModelView, worldPos).xyzz * diagonal4(gl_ProjectionMatrix) + gl_ProjectionMatrix[3];

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
