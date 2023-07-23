/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/include/utility/sampling.glsl"

// Originally written by Capt Tatsu
// Modified it myself
vec3 computeStarfield(vec3 viewPosition) {
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
	return max0(saturate(star - (1.0 - STARS_AMOUNT * 2e-3)) * factor * STARS_LUMINOSITY * blackbody(mix(STARS_MIN_TEMP, STARS_MAX_TEMP, rand(coords))));
}

vec3 physicalSun(vec3 sceneDir) {
    return dot(sceneDir, sunVector) < cos(sunAngularRadius) ? vec3(0.0) : sunRadiance * RCP_PI;
}

vec3 physicalMoon(vec3 sceneDir) {
    vec2 sphere = intersectSphere(-moonVector, sceneDir, moonAngularRadius);

	Material moonMaterial;
	moonMaterial.normal    = normalize(sceneDir * sphere.x - moonVector);
	moonMaterial.albedo    = vec3(moonAlbedo);
	moonMaterial.roughness = moonRoughness;
	moonMaterial.F0		   = 0.0;

    return sphere.y < 0.0 ? vec3(0.0) : moonMaterial.albedo * hammonDiffuse(moonMaterial, -sceneDir, sunVector) * sunIrradiance;
}

vec3 physicalStar(vec3 sceneDir) {
    return dot(sceneDir, starVector) < cos(starAngularRadius) ? vec3(0.0) : starRadiance * RCP_PI;
}

vec3 renderAtmosphere(vec2 coords, vec3 viewPosition) {
	#if defined WORLD_OVERWORLD || defined WORLD_END
		vec3 sceneDir = normalize(viewToScene(viewPosition));
		vec3 sky      = texture(ATMOSPHERE_BUFFER, saturate(projectSphere(sceneDir) + randF() * pixelSize)).rgb;

		vec4 clouds = vec4(0.0, 0.0, 0.0, 1.0);
		#if defined WORLD_OVERWORLD
			#if CLOUDS_LAYER0_ENABLED == 1 || CLOUDS_LAYER1_ENABLED == 1
				clouds = texture(CLOUDS_BUFFER, saturate(coords + randF() * pixelSize));
			#endif

			sky += clamp16(physicalSun (sceneDir));
			sky += clamp16(physicalMoon(sceneDir));
		#elif defined WORLD_END
			sky += clamp16(physicalStar(sceneDir));
		#endif

		sky += computeStarfield(viewPosition);

		return sky * clouds.a + clouds.rgb;
	#else
		return vec3(0.0);
	#endif
}
