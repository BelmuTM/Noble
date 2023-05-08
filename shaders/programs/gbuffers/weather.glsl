/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/include/common.glsl"

#if defined STAGE_VERTEX

	out vec2 textureCoords;
	out vec3 skyIlluminance;
	
	#include "/include/atmospherics/atmosphere.glsl"

	void main() {
		textureCoords = gl_MultiTexCoord0.xy;

		vec3 worldPosition = transform(gbufferModelViewInverse, transform(gl_ModelViewMatrix, gl_Vertex.xyz));

		#if RENDER_MODE == 0
			worldPosition.xz += RAIN_DIRECTION * worldPosition.y;
		#endif

		gl_Position = transform(gbufferModelView, worldPosition).xyzz * diagonal4(gl_ProjectionMatrix) + gl_ProjectionMatrix[3];

		skyIlluminance = evaluateUniformSkyIrradianceApproximation();
	}

#elif defined STAGE_FRAGMENT

	/* RENDERTARGETS: 4 */

	layout (location = 0) out vec4 color;

	in vec2 textureCoords;
	in vec3 skyIlluminance;

	void main() {
		if(texture(tex, textureCoords).a < 0.102) discard;

		const float density					= 0.1;
		const float scatteringCoefficient   = 0.2;
		const vec3  attenuationCoefficients = vec3(0.338675, 0.0493852, 0.00218174); // Provided by Jessie
		const float alpha					= 0.4;

		color.rgb = skyIlluminance * exp(-attenuationCoefficients * density) * scatteringCoefficient;
		color.a   = alpha;
	}
#endif
