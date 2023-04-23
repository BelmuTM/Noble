/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/include/utility/sampling.glsl"

// Originally written by Capt Tatsu#7124
// Modified by Belmu#4066
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
	return max0(saturate(star - (1.0 - STARS_AMOUNT)) * factor * STARS_BRIGHTNESS * blackbody(mix(STARS_MIN_TEMP, STARS_MAX_TEMP, rand(coords))));
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

vec3 computeAtmosphere(vec3 viewPosition) {
	#if defined WORLD_OVERWORLD
		vec3 sceneDir = normalize(viewToScene(viewPosition));
    	vec2 coords   = projectSphere(sceneDir);

		vec3 sky = textureCatmullRom(ATMOSPHERE_BUFFER, saturate(coords + randF() * pixelSize)).rgb;

		vec4 clouds = vec4(0.0, 0.0, 0.0, 1.0);
		#if PRIMARY_CLOUDS == 1 || SECONDARY_CLOUDS == 1
			clouds = textureCatmullRom(CLOUDS_BUFFER, texCoords);
		#endif

		sky += physicalSun(sceneDir);
		sky += physicalMoon(sceneDir);
		sky += computeStarfield(viewPosition);

		return sky * clouds.a + clouds.rgb;
	#else
		return vec3(0.0);
	#endif
}
