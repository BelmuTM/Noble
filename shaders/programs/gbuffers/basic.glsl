/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#if defined STAGE_VERTEX
	#define PROGRAM_BASIC
	#include "/programs/gbuffers/gbuffers.vsh"

#elif defined STAGE_FRAGMENT
	/* RENDERTARGETS: 13 */

	layout (location = 0) out vec4 color;

	in vec2 texCoords;
	in vec4 vertexColor;

	uniform sampler2D colortex0;

	void main() {
		vec4 albedoTex  = texture(colortex0, texCoords);
		     albedoTex *= vertexColor;

		color = albedoTex;
	}
#endif
