/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#define attribute in
attribute vec4 at_tangent;
attribute vec3 mc_Entity;
attribute vec2 mc_midTexCoord;

flat out int blockId;
out vec2 textureCoords;
out vec2 lightmapCoords;
out vec2 texSize;
out vec2 botLeft;
out vec3 viewPosition;
out vec4 vertexColor;
out mat3 tbn;

#define STAGE_VERTEX

#include "/include/common.glsl"
#include "/include/vertex/animation.glsl"

void main() {
	#if defined PROGRAM_HAND && DISCARD_HAND == 1
		gl_Position = vec4(1.0);
		return;
	#endif

	textureCoords  = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lightmapCoords = gl_MultiTexCoord1.xy * rcp(240.0);
	vertexColor    = gl_Color;

	#if POM > 0 && defined PROGRAM_TERRAIN
		vec2 halfSize = abs(textureCoords - mc_midTexCoord);
		texSize       = halfSize * 2.0;
		botLeft       = mc_midTexCoord - halfSize;
	#endif

	#if !defined PROGRAM_BASIC 
    	viewPosition = transform(gl_ModelViewMatrix, gl_Vertex.xyz);

    	tbn[2] = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * gl_Normal);
    	tbn[0] = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * at_tangent.xyz);
		tbn[1] = cross(tbn[0], tbn[2]) * sign(at_tangent.w);
	#endif

	blockId = int((mc_Entity.x - 1000.0) + 0.25);
	
	vec3 worldPosition = transform(gbufferModelViewInverse, viewPosition);

	#if RENDER_MODE == 0
		#if WAVING_PLANTS == 1
			#if defined PROGRAM_TERRAIN
				animate(worldPosition, textureCoords.y < mc_midTexCoord.y, getSkylightFalloff(lightmapCoords.y));
			#endif
		#endif

		#if defined PROGRAM_WEATHER
			worldPosition.xz += RAIN_DIRECTION * worldPosition.y;
		#endif
	#endif
	
	gl_Position = transform(gbufferModelView, worldPosition).xyzz * diagonal4(gl_ProjectionMatrix) + gl_ProjectionMatrix[3];

	#if defined PROGRAM_ENTITY
		// Thanks Niemand#1929 for the nametag fix
		if(vertexColor.a >= 0.24 && vertexColor.a < 0.255) {
			gl_Position = vec4(10.0, 10.0, 10.0, 1.0);
		}
	#endif

	#if TAA == 1
		gl_Position.xy += taaJitter(gl_Position);
	#endif
}
