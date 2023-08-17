/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/settings.glsl"
#include "/include/taau_scale.glsl"

#include "/include/common.glsl"

#if defined STAGE_VERTEX

	out vec2 textureCoords;
	out vec3 skyIlluminance;
	
	#include "/include/atmospherics/constants.glsl"

	#include "/include/utility/phase.glsl"
	#include "/include/atmospherics/atmosphere.glsl"

	void main() {
		textureCoords = gl_MultiTexCoord0.xy;

		vec3 worldPosition = transform(gbufferModelViewInverse, transform(gl_ModelViewMatrix, gl_Vertex.xyz));

		#if RENDER_MODE == 0
			worldPosition.xz += RAIN_DIRECTION * worldPosition.y;
		#endif

		gl_Position    = transform(gbufferModelView, worldPosition).xyzz * diagonal4(gl_ProjectionMatrix) + gl_ProjectionMatrix[3];
		gl_Position.xy = gl_Position.xy * RENDER_SCALE + (RENDER_SCALE - 1.0) * gl_Position.w;

		skyIlluminance = evaluateUniformSkyIrradianceApproximation();
	}

#elif defined STAGE_FRAGMENT

	/* RENDERTARGETS: 4 */

	layout (location = 0) out vec4 color;

	in vec2 textureCoords;
	in vec3 skyIlluminance;

	void main() {
		vec2 fragCoords = gl_FragCoord.xy * texelSize / RENDER_SCALE;
		if(saturate(fragCoords) != fragCoords) discard;

		if(texture(tex, textureCoords).a < 0.102) discard;

		const float density               = 2.0;
		const float scatteringCoefficient = 0.1;
		const float alpha                 = 0.3;

		vec3 attenuationCoefficients = vec3(0.338675, 0.0493852, 0.00218174);

		#if TONEMAP == ACES
			attenuationCoefficients *= SRGB_2_AP1_ALBEDO;
		#endif

		color.rgb = skyIlluminance * exp(-attenuationCoefficients * density) * scatteringCoefficient;
		color.a   = alpha;
	}
#endif
