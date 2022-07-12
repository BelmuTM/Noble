/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#ifdef STAGE_VERTEX
	#define PROGRAM_BASIC
	#include "/programs/gbuffers/gbuffers.vsh"

#elif defined STAGE_FRAGMENT
	/* RENDERTARGETS: 1 */

	layout (location = 0) out uvec4 data;

	in vec2 texCoords;
	in vec2 lmCoords;
	in vec4 vertexColor;

	#include "/include/uniforms.glsl"

	void main() {
		vec3 color = vec3(0.0);

		data.x = packUnorm4x8(vec4(1.0, 0.0, lmCoords));
		data.y = packUnorm4x8(vec4(1.0, 1.0, 1.0, 1.0));
		data.z = (uint(color.r * maxVal8) << 16u)  | (uint(color.g * maxVal8) << 8u) | uint(color.b * maxVal8);
		data.w = 0u;
	}
#endif
