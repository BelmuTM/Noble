/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

attribute vec4 at_tangent;
attribute vec3 mc_Entity;

out int blockId;
out vec2 texCoords;
out vec2 lmCoords;
out vec3 viewPos;
out vec3 waterNormals;
out vec3 skyIlluminance;
out vec3 shadowLightTransmit;
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
    viewPos     = transMAD3(gl_ModelViewMatrix, gl_Vertex.xyz);

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

    #ifdef WORLD_OVERWORLD
        const ivec2 samples = ivec2(16, 8);

        for(int x = 0; x < samples.x; x++) {
            for(int y = 0; y < samples.y; y++) {
                vec3 dir = generateUnitVector(vec2(x, y) / samples);
                     dir = dot(dir, vec3(0.0, 1.0, 0.0)) < 0.0 ? -dir : dir; // Thanks SixthSurge for the help with hemisphere sampling

                skyIlluminance += texture(colortex6, projectSphere(dir) * ATMOSPHERE_RESOLUTION).rgb;
            }
        }
        skyIlluminance     *= (1.0 / (samples.x * samples.y));
		shadowLightTransmit = shadowLightTransmittance();
    #endif

	#if TAA == 1
		bool canJitter = ACCUMULATION_VELOCITY_WEIGHT == 0 ? true : hasMoved();
		if(canJitter) { gl_Position.xy += taaJitter(gl_Position); }
    #endif
}
