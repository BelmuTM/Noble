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

flat out int blockId;
out vec2 texCoords;
out vec2 lmCoords;
out vec3 viewPos;
out vec3 waterNormals;
out vec3 skyIlluminance;
out vec3 directLightTransmit;
out vec4 vertexColor;
out mat3 TBN;

#include "/include/fragment/water.glsl"

#include "/include/atmospherics/celestial.glsl"
#include "/include/atmospherics/atmosphere.glsl"

void main() {
	texCoords   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmCoords    = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	vertexColor = gl_Color;

    vec3 normal = mat3(gbufferModelViewInverse) * (gl_NormalMatrix * gl_Normal);
    viewPos     = transMAD(gl_ModelViewMatrix, gl_Vertex.xyz);

    vec3 tangent = mat3(gbufferModelViewInverse) * (gl_NormalMatrix * (at_tangent.xyz / at_tangent.w));
	TBN 		 = mat3(tangent, cross(tangent, normal), normal);

	blockId 	= int((mc_Entity.x - 1000.0) + 0.25);
	gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;

	if(int(blockId + 0.5) == 1) {
		vec3 worldPos = viewToWorld(viewPos);
		worldPos.y   += calculateWaterWaves(worldPos.xz);
		waterNormals  = getWaveNormals(worldPos);

    	vec4 viewToClip = gl_ProjectionMatrix * vec4(worldToView(worldPos), 1.0);
		gl_Position     = viewToClip;
	}

    skyIlluminance = sampleSkyIlluminance();

	#if TAA == 1
		bool canJitter = ACCUMULATION_VELOCITY_WEIGHT == 0 ? true : hasMoved();
		if(canJitter) { gl_Position.xy += taaJitter(gl_Position); }
    #endif
}
