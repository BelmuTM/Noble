/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/settings.glsl"
#include "/include/utility/uniforms.glsl"

#if defined STAGE_VERTEX

	out vec2 texCoords;
	out vec3 geoNormal;
	out vec3 directIlluminance;
	out vec4 vertexColor;

	#if TAA == 1
		#include "/include/utility/rng.glsl"
	#endif

	void main() {
		gl_Position = ftransform();
		texCoords   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
		vertexColor = gl_Color;

		geoNormal = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * gl_Normal);

		#if TAA == 1
			gl_Position.xy += taaJitter(gl_Position);
   		#endif

		directIlluminance = texelFetch(ILLUMINANCE_BUFFER, ivec2(0), 0).rgb;
	}

#elif defined STAGE_FRAGMENT

	/* RENDERTARGETS: 15 */

	layout (location = 0) out vec4 color;

	in vec2 texCoords;
	in vec3 geoNormal;
	in vec3 directIlluminance;
	in vec4 vertexColor;

	#include "/include/utility/math.glsl"

	void main() {
		vec4 albedoTex = texture(tex, texCoords);
		if(albedoTex.a < 0.102) discard;

		color 	  = albedoTex * vertexColor;
		color.rgb = color.rgb * RCP_PI * saturate(dot(geoNormal, shadowLightVector)) * directIlluminance;
	}
#endif
