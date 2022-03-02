/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

// Originally written by Capt Tatsu#7124
// Modified by Belmu#4066
float computeStarfield(vec3 viewPos) {
	vec3 scenePos    = mat3(gbufferModelViewInverse) * viewPos;
	vec3 planeCoords = scenePos / (scenePos.y + length(scenePos.xz));
	vec2 coords 	 = planeCoords.xz * 0.9 + cameraPosition.xz * 1e-5 + frameTime * 0.00125;
	coords 			 = floor(coords * 1024.0) / 1024.0;

	float VdotU  = clamp01(dot(normalize(viewPos), normalize(upPosition)));
	float factor = sqrt(sqrt(VdotU)) * (1.0 - rainStrength);

	float star = 1.0;
	if(VdotU > 0.0) {
		star *= rand( coords.xy);
		star *= rand(-coords.xy + 0.1);
	}
	return max0(star - (1.0 - STARS_AMOUNT)) * factor;
}

vec3 physicalSun(vec3 sceneDir) {
    float VdotL = dot(sceneDir, sceneSunDir);
    return VdotL < cos(sunAngularRad) ? vec3(0.0) : sunLuminance * INV_PI;
}

vec3 physicalMoon(vec3 sceneDir) {
    vec2 sphere     = intersectSphere(-sceneMoonDir, sceneDir, moonAngularRad);
    vec3 moonNormal = normalize(sceneDir * sphere.x - sceneMoonDir);

	Material moonMat;
	moonMat.albedo = vec3(moonAlbedo);
	moonMat.rough  = moonRoughness;
    vec3 diffuse   = hammonDiffuse(moonNormal, -sceneDir, sceneSunDir, moonMat, false);

    return sphere.y < 0.0 ? vec3(0.0) : moonMat.albedo * diffuse * sunIlluminance;
}

vec3 computeSky(vec3 viewPos, bool starfield) {
	#ifdef WORLD_OVERWORLD
		vec3 sceneDir = normalize(viewToScene(viewPos));

    	vec2 coords     = projectSphere(sceneDir);
    	vec3 starsColor = blackbody(mix(STARS_MIN_TEMP, STARS_MAX_TEMP, rand(coords)));

    	#if TAA == 1
        	float jitter = randF();
    	#else
        	float jitter = bayer8(gl_FragCoord.xy);
    	#endif

		vec3 stars = vec3(0.0);
    	if(starfield) { stars = computeStarfield(viewPos) * STARS_BRIGHTNESS * starsColor; }

		vec3 sky   = texture(colortex6, (coords * ATMOSPHERE_RESOLUTION) + (jitter * pixelSize)).rgb;
		vec3 sun   = physicalSun(sceneDir);
		vec3 moon  = physicalMoon(sceneDir);

		return sky + stars + sun + moon;
	#else
		return vec3(0.0);
	#endif
}
