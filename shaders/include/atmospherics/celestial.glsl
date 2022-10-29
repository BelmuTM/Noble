/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

// Originally written by Capt Tatsu#7124
// Modified by Belmu#4066
vec3 computeStarfield(vec3 viewPos) {
	vec3 scenePos    = viewToScene(viewPos);
	vec3 planeCoords = scenePos / (scenePos.y + length(scenePos.xz));
	vec2 coords 	 = planeCoords.xz * 0.9 + cameraPosition.xz * 1e-5 + frameTime * 0.00125;
	     coords 	 = floor(coords * 1024.0) * rcp(1024.0);

	float VdotU  = clamp01(dot(normalize(viewPos), normalize(upPosition)));
	float factor = sqrt(sqrt(VdotU)) * (1.0 - rainStrength);

	float star = 1.0;
	if(VdotU > 0.0) {
		star *= rand( coords.xy);
		star *= rand(-coords.xy + 0.1);
	}
	return max0(clamp01(star - (1.0 - STARS_AMOUNT)) * factor * STARS_BRIGHTNESS * blackbody(mix(STARS_MIN_TEMP, STARS_MAX_TEMP, rand(coords))));
}

vec3 physicalSun(vec3 sceneDir) {
    return dot(sceneDir, sunVector) < cos(sunAngularRad) ? vec3(0.0) : sunLuminance * RCP_PI;
}

vec3 physicalMoon(vec3 sceneDir) {
    vec2 sphere = intersectSphere(-moonVector, sceneDir, moonAngularRad);

	Material moonMat;
	moonMat.normal = normalize(sceneDir * sphere.x - moonVector);
	moonMat.albedo = vec3(moonAlbedo);
	moonMat.rough  = moonRoughness;

    return sphere.y < 0.0 ? vec3(0.0) : moonMat.albedo * hammonDiffuse(moonMat, -sceneDir, sunVector) * sunIlluminance;
}

vec3 computeSky(vec3 viewPos) {
	#ifdef WORLD_OVERWORLD
		vec3 sceneDir    = normalize(viewToScene(viewPos));
    	vec2 coords      = projectSphere(sceneDir);

		vec3 sky = texture(colortex0, getAtmosphereCoordinates(coords, ATMOSPHERE_RESOLUTION, randF())).rgb;

		vec4 clouds = vec4(0.0, 0.0, 0.0, 1.0);
		#if VOLUMETRIC_CLOUDS == 1 || PLANAR_CLOUDS == 1
			clouds = textureCatmullRom(colortex12, getAtmosphereCoordinates(texCoords, CLOUDS_RESOLUTION, 0.0));
		#endif

		sky += physicalSun(sceneDir);
		sky += physicalMoon(sceneDir);
		sky += computeStarfield(viewPos);

		return sky * clouds.a + clouds.rgb;
	#else
		return vec3(0.0);
	#endif
}
