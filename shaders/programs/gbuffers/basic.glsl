/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/include/taau_scale.glsl"

#include "/settings.glsl"
#include "/include/uniforms.glsl"

#include "/include/utility/rng.glsl"
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
			vec3 worldPosition = transform(gbufferModelViewInverse, viewPosition);
			gl_Position        = transform(gbufferModelView, worldPosition).xyzz * diagonal4(gl_ProjectionMatrix) + gl_ProjectionMatrix[3];
		#else
			gl_Position = ftransform();
		#endif

		gl_Position.xy = gl_Position.xy * RENDER_SCALE + (RENDER_SCALE - 1.0) * gl_Position.w;

		#if TAA == 1 && EIGHT_BITS_FILTER == 0
			gl_Position.xy += taaJitter(gl_Position);
		#endif
	}

#elif defined STAGE_FRAGMENT

	/* RENDERTARGETS: 15 */

	layout (location = 0) out vec4 color;

	in vec2 textureCoords;
	in vec4 vertexColor;

	void main() {
		vec2 fragCoords = gl_FragCoord.xy * pixelSize / RENDER_SCALE;
		if(saturate(fragCoords) != fragCoords) discard;

		vec4 albedoTex = texture(tex, textureCoords) * vertexColor;
		if(albedoTex.a < 0.102) discard;

		color = albedoTex;
	}
#endif
