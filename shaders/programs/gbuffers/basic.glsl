/********************************************************************************/
/*                                                                              */
/*    Noble Shaders                                                             */
/*    Copyright (C) 2025  Belmu                                                 */
/*                                                                              */
/*    This program is free software: you can redistribute it and/or modify      */
/*    it under the terms of the GNU General Public License as published by      */
/*    the Free Software Foundation, either version 3 of the License, or         */
/*    (at your option) any later version.                                       */
/*                                                                              */
/*    This program is distributed in the hope that it will be useful,           */
/*    but WITHOUT ANY WARRANTY; without even the implied warranty of            */
/*    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the             */
/*    GNU General Public License for more details.                              */
/*                                                                              */
/*    You should have received a copy of the GNU General Public License         */
/*    along with this program.  If not, see <https://www.gnu.org/licenses/>.    */
/*                                                                              */
/********************************************************************************/

#include "/settings.glsl"
#include "/include/uniforms.glsl"

#include "/include/taau_scale.glsl"

#include "/include/utility/math.glsl"
#include "/include/utility/transforms.glsl"

#if defined STAGE_VERTEX

	out vec2 textureCoords;
	out vec4 vertexColor;

	void main() {
		textureCoords = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
		vertexColor   = gl_Color;

		#if defined PROGRAM_ARMOR_GLINT
			vec3 viewPosition  = transform(gl_ModelViewMatrix, gl_Vertex.xyz);
			vec3 scenePosition = transform(gbufferModelViewInverse, viewPosition);
			gl_Position        = project(gl_ProjectionMatrix, transform(gbufferModelView, scenePosition));
		#else
			gl_Position = ftransform();
		#endif

		gl_Position.xy = gl_Position.xy * RENDER_SCALE + (RENDER_SCALE - 1.0) * gl_Position.w;

		#if TAA == 1
			gl_Position.xy += taaJitter(gl_Position);
		#endif
	}

#elif defined STAGE_FRAGMENT

	/* RENDERTARGETS: 15 */

	layout (location = 0) out vec4 color;

	in vec2 textureCoords;
	in vec4 vertexColor;

	uniform sampler2D gtexture;

	void main() {
		vec2 fragCoords = gl_FragCoord.xy * texelSize / RENDER_SCALE;
		if(saturate(fragCoords) != fragCoords) discard;

		vec4 albedoTex = texture(gtexture, textureCoords);

		#if defined PROGRAM_ARMOR_GLINT
			color = vec4(albedoTex.rgb, 0.0);
		#elif defined PROGRAM_DAMAGED_BLOCK

			if(albedoTex.a < 0.102) discard;

			color = vec4(albedoTex.rgb, 1e-4);

		#else
			if(albedoTex.a < 0.102) discard;

			albedoTex.rgb *= vertexColor.rgb;

			color = albedoTex;
		#endif
	}
	
#endif
