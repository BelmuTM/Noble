/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#if defined STAGE_VERTEX

	out vec2 texCoords;
	out vec4 vertexColor;

	#include "/include/common.glsl"

	void main() {
		gl_Position = ftransform();
		texCoords   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
		vertexColor = gl_Color;

		#if TAA == 1
			gl_Position.xy += taaJitter(gl_Position);
   		#endif
	}

#elif defined STAGE_FRAGMENT

	/* RENDERTARGETS: 14 */

	layout (location = 0) out vec4 color;

	in vec2 texCoords;
	in vec4 vertexColor;

	uniform sampler2D colortex0;

	void main() {
		vec4 albedoTex  = texture(colortex0, texCoords);
		if(albedoTex.a < 0.102) discard;

		color = albedoTex * vertexColor;
	}
#endif
