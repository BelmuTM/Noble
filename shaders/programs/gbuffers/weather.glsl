/***********************************************/
/*          Copyright (C) 2024 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/settings.glsl"
#include "/include/taau_scale.glsl"

#include "/include/common.glsl"

#define MIN_RAIN_BRIGHTNESS 6.0

#if defined STAGE_VERTEX

	out vec2 textureCoords;
	out vec3 directIlluminance;

	void main() {
		textureCoords = gl_MultiTexCoord0.xy;

		directIlluminance = max(texelFetch(ILLUMINANCE_BUFFER, ivec2(0), 0).rgb, vec3(MIN_RAIN_BRIGHTNESS));

		vec3 scenePosition = transform(gbufferModelViewInverse, transform(gl_ModelViewMatrix, gl_Vertex.xyz));

		#if WEATHER_TILT == 1
			const float weatherTiltAngleX = radians(WEATHER_TILT_ANGLE_X), weatherTiltAngleZ = radians(WEATHER_TILT_ANGLE_Z);

			vec2 weatherTiltRotation = vec2(cos(weatherTiltAngleX), sin(weatherTiltAngleZ));
			vec2 weatherTiltOffset   = weatherTiltRotation * (cos(length(scenePosition + cameraPosition) * 5.0) * 0.2 + 0.8);

			scenePosition.xz += weatherTiltOffset * scenePosition.y;
		#endif

		gl_Position    = project(gl_ProjectionMatrix, transform(gbufferModelView, scenePosition));
		gl_Position.xy = gl_Position.xy * RENDER_SCALE + (RENDER_SCALE - 1.0) * gl_Position.w;
	}

#elif defined STAGE_FRAGMENT

	/* RENDERTARGETS: 13 */

	layout (location = 0) out vec4 color;

	in vec2 textureCoords;
	in vec3 directIlluminance;

	vec4 computeRainColor() {
		const float density               = 1.0;
		const float scatteringCoefficient = 0.1;
		const float alpha                 = 0.1;

		#if TONEMAP == ACES
			const vec3 attenuationCoefficients = vec3(0.338675, 0.0493852, 0.00218174) * SRGB_2_AP1_ALBEDO;
		#else
			const vec3 attenuationCoefficients = vec3(0.338675, 0.0493852, 0.00218174);
		#endif

		return vec4(exp(-attenuationCoefficients * density) * scatteringCoefficient, alpha);
	}

	void main() {
		vec2 fragCoords = gl_FragCoord.xy * texelSize / RENDER_SCALE;
		if(saturate(fragCoords) != fragCoords) discard;

		vec4 albedo = texture(tex, textureCoords);

		if(albedo.a < 0.102) discard;

		bool isRain = (abs(albedo.r - albedo.b) > EPS);

		if(isRain) {
			color = computeRainColor();
		} else {
			color = vec4(1.0, 1.0, 1.0, 0.1);
		}

		color.rgb *= directIlluminance;
	}
	
#endif
