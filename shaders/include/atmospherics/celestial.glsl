/***********************************************/
/*          Copyright (C) 2024 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

uniform vec3 upPosition;

#include "/include/utility/sampling.glsl"

float computeStarfield(vec3 viewPosition, vec3 lightVector) {
	vec3 sceneDirection = normalize(viewToScene(viewPosition));
		 sceneDirection = rotate(sceneDirection, lightVector, vec3(0.0, 0.0, 1.0));

	vec3  position = sceneDirection * STARS_SCALE;
	vec3  index    = floor(position);
	float radius   = lengthSqr(position - index - 0.5);

	float VdotU  = saturate(dot(normalize(viewPosition), upPosition));
	float factor = max0(sqrt(sqrt(VdotU)));

	float falloff = pow2(quinticStep(0.5, 0.0, radius));

	float rng = hash13(index);

	float star = 1.0;
	if(VdotU > 0.0) {
		star *= rng;
		star *= hash13(-index + 0.1);
	}
	star = saturate(star - (1.0 - STARS_AMOUNT * 0.0025));

	float luminosity = STARS_LUMINANCE * luminance(blackbody(mix(STARS_MIN_TEMP, STARS_MAX_TEMP, rng)));

	return star * factor * falloff * luminosity;
}

vec3 physicalSun(vec3 sceneDirection) {
    return dot(sceneDirection, sunVector) < cos(sunAngularRadius) ? vec3(0.0) : sunRadiance * RCP_PI;
}

vec3 physicalMoon(vec3 sceneDirection) {
    vec2 sphere = intersectSphere(-moonVector, sceneDirection, moonAngularRadius);

	Material moonMaterial;
	moonMaterial.normal    = normalize(sceneDirection * sphere.x - moonVector);
	moonMaterial.albedo    = vec3(moonAlbedo);
	moonMaterial.roughness = moonRoughness;
	moonMaterial.F0		   = 0.0;

    return sphere.y < 0.0 ? vec3(0.0) : moonMaterial.albedo * hammonDiffuse(moonMaterial, -sceneDirection, sunVector) * sunIrradiance;
}

vec3 physicalStar(vec3 sceneDirection) {
    return dot(sceneDirection, starVector) < cos(starAngularRadius) ? vec3(0.0) : starRadiance * RCP_PI;
}

vec3 renderAtmosphere(vec2 coords, vec3 viewPosition, vec3 directIlluminance, vec3 skyIlluminance) {
	#if defined WORLD_OVERWORLD || defined WORLD_END
		float jitter = interleavedGradientNoise(gl_FragCoord.xy);

		vec3 sceneDirection = normalize(viewToScene(viewPosition));
		vec3 sky            = textureBicubic(ATMOSPHERE_BUFFER, saturate(projectSphere(sceneDirection) + jitter * texelSize)).rgb;

		vec4 clouds = vec4(0.0, 0.0, 0.0, 1.0);
		#if defined WORLD_OVERWORLD
			#if CLOUDS_LAYER0_ENABLED == 1 || CLOUDS_LAYER1_ENABLED == 1
				vec3 cloudsBuffer = texture(CLOUDS_BUFFER, coords * rcp(RENDER_SCALE)).rgb;

				clouds.rgb = cloudsBuffer.r * directIlluminance + cloudsBuffer.g * skyIlluminance;
				clouds.a   = cloudsBuffer.b;
			#endif

			sky += physicalSun (sceneDirection);
			sky += physicalMoon(sceneDirection);
		#elif defined WORLD_END
			sky += physicalStar(sceneDirection);
		#endif

		#if defined WORLD_OVERWORLD
			sky += computeStarfield(viewPosition, sunVector);
		#elif defined WORLD_END
			sky += computeStarfield(viewPosition, starVector) * 4.0;
		#endif

		return sky * clouds.a + clouds.rgb;
	#else
		return vec3(0.0);
	#endif
}
