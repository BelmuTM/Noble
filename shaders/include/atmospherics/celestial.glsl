/***********************************************/
/*          Copyright (C) 2024 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/include/utility/sampling.glsl"

// Originally written by Capt Tatsu
// Modified it myself
float computeStarfield(vec3 viewPosition) {
	vec3 scenePosition = viewToScene(viewPosition);
	vec3 planeCoords   = scenePosition / (scenePosition.y + length(scenePosition.xz));
	vec2 coords 	   = planeCoords.xz * 0.9 + cameraPosition.xz * 1e-5 + frameTime * 0.00125;
	     coords 	   = floor(coords * 1024.0) * rcp(1024.0);

	float VdotU  = saturate(dot(normalize(viewPosition), normalize(upPosition)));
	float factor = sqrt(sqrt(VdotU)) * (1.0 - rainStrength);

	float star = 1.0;
	if(VdotU > 0.0) {
		star *= rand( coords.xy);
		star *= rand(-coords.xy + 0.1);
	}
	return max0(saturate(star - (1.0 - STARS_AMOUNT * 2e-3)) * factor * STARS_LUMINOSITY * luminance(blackbody(mix(STARS_MIN_TEMP, STARS_MAX_TEMP, rand(coords)))));
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
		vec3 sky            = textureCatmullRom(ATMOSPHERE_BUFFER, saturate(projectSphere(sceneDirection) + jitter * texelSize)).rgb;

		vec4 clouds = vec4(0.0, 0.0, 0.0, 1.0);
		#if defined WORLD_OVERWORLD
			#if CLOUDS_LAYER0_ENABLED == 1 || CLOUDS_LAYER1_ENABLED == 1
				vec3 cloudsBuffer = texture(CLOUDS_BUFFER, coords).rgb;

				clouds.rgb = cloudsBuffer.r * directIlluminance + cloudsBuffer.g * skyIlluminance;
				clouds.a   = cloudsBuffer.b;
			#endif

			sky += physicalSun (sceneDirection);
			sky += physicalMoon(sceneDirection);
		#elif defined WORLD_END
			sky += physicalStar(sceneDirection);
		#endif

		sky += computeStarfield(viewPosition);

		return sky * clouds.a + clouds.rgb;
	#else
		return vec3(0.0);
	#endif
}
