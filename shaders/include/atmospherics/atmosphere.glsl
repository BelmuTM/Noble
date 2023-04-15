/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

/*
    [Credits]:
        Jessie - help with atmospheric scattering and providing ozone cross section approximation (https://github.com/Jessie-LC)
        Zombye - sky illuminance sampling approximation (https://github.com/zombye)
        
    [References]:
        Nishita, T. (1993). Display of the earth taking into account atmospheric scattering. http://nishitalab.org/user/nis/cdrom/sig93_nis.pdf
        Elek, O. (2009). Rendering Parametrizable Planetary Atmospheres with Multiple Scattering in Real-Time. https://old.cescg.org/CESCG-2009/papers/PragueCUNI-Elek-Oskar09.pdf
*/

vec3 getAtmosphereDensities(float centerDist) {
	float altitudeKm = (centerDist - planetRadius) * 1e-3;
	vec2 rayleighMie = exp(altitudeKm / -(scaleHeights * 1e-3));

    // Ozone approximation from Jessie#7257
    float o1 = 25.0 *     exp(( 0.0 - altitudeKm) * rcp(  8.0));
    float o2 = 30.0 * pow(exp((18.0 - altitudeKm) * rcp( 80.0)), altitudeKm - 18.0);
    float o3 = 75.0 * pow(exp((25.3 - altitudeKm) * rcp( 35.0)), altitudeKm - 25.3);
    float o4 = 50.0 * pow(exp((30.0 - altitudeKm) * rcp(150.0)), altitudeKm - 30.0);
    float ozone = (o1 + o2 + o3 + o4) * rcp(134.628);

	return vec3(rayleighMie, ozone);
}

vec3 getAtmosphereTransmittance(vec3 rayOrigin, vec3 lightDir) {
    float stepSize = intersectSphere(rayOrigin, lightDir, atmosphereUpperRadius).y * rcp(TRANSMITTANCE_STEPS);
    vec3 increment = lightDir * stepSize;
    vec3 rayPos    = rayOrigin + increment * 0.5;

    vec3 accumAirmass = vec3(0.0);
    for(int i = 0; i < TRANSMITTANCE_STEPS; i++, rayPos += increment) {
        accumAirmass += getAtmosphereDensities(length(rayPos)) * stepSize;
    }
    return exp(-atmosphereExtinctionCoefficients * accumAirmass);
}

#if defined STAGE_FRAGMENT
    vec3 atmosphericScattering(vec3 rayDir, vec3 skyIlluminance) {
        vec2 dists = intersectSphericalShell(atmosphereRayPosition, rayDir, atmosphereLowerRadius, atmosphereUpperRadius);
        if(dists.y < 0.0) return vec3(0.0);

        float stepSize = (dists.y - dists.x) * rcp(SCATTERING_STEPS);
        vec3 increment = rayDir * stepSize;
        vec3 rayPos    = atmosphereRayPosition + increment * 0.5;

        vec2 VdotL = vec2(dot(rayDir, sunVector), dot(rayDir, moonVector));
        vec4 phase = vec4(
            vec2(rayleighPhase(VdotL.x), kleinNishinaPhase(VdotL.x, mieAnisotropyFactor)), 
            vec2(rayleighPhase(VdotL.y), kleinNishinaPhase(VdotL.y, mieAnisotropyFactor))
        );

        mat2x3 scattering = mat2x3(vec3(0.0), vec3(0.0)); vec3 multipleScattering = vec3(0.0); vec3 transmittance = vec3(1.0);
    
        for(int i = 0; i < SCATTERING_STEPS; i++, rayPos += increment) {
            vec3 airmass          = getAtmosphereDensities(length(rayPos)) * stepSize;
            vec3 stepOpticalDepth = atmosphereExtinctionCoefficients * airmass;

            vec3 stepTransmittance  = exp(-stepOpticalDepth);
            vec3 visibleScattering  = transmittance                    * clamp01((stepTransmittance - 1.0) / -stepOpticalDepth);
            vec3 sunStepScattering  = atmosphereScatteringCoefficients * (airmass.xy * phase.xy) * visibleScattering;
            vec3 moonStepScattering = atmosphereScatteringCoefficients * (airmass.xy * phase.zw) * visibleScattering;

            scattering[0] += sunStepScattering  * getAtmosphereTransmittance(rayPos, sunPosNorm);
            scattering[1] += moonStepScattering * getAtmosphereTransmittance(rayPos,-sunPosNorm);

            vec3 stepScattering    = atmosphereScatteringCoefficients * airmass.xy;
            vec3 stepScatterAlbedo = stepScattering / stepOpticalDepth;

            vec3 multScatteringFactor = stepScatterAlbedo * 0.84;
            vec3 multScatteringEnergy = multScatteringFactor / (1.0 - multScatteringFactor);
                 multipleScattering  += multScatteringEnergy * visibleScattering * stepScattering;

            transmittance *= stepTransmittance;
        }
        multipleScattering *= skyIlluminance * isotropicPhase;
        scattering[0]      *= sunIlluminance;
        scattering[1]      *= moonIlluminance;
    
        return scattering[0] + scattering[1] + multipleScattering;
    }
#endif

vec3 sampleDirectIlluminance() {
    vec3 directIlluminance = vec3(0.0);

    #if defined WORLD_OVERWORLD
        vec3 sunTransmit  = getAtmosphereTransmittance(atmosphereRayPosition, sunPosNorm) * sunIlluminance;
        vec3 moonTransmit = getAtmosphereTransmittance(atmosphereRayPosition,-sunPosNorm) * moonIlluminance;
        directIlluminance = sunTransmit + moonTransmit;

        #if TONEMAP == ACES
            directIlluminance *= SRGB_2_AP1_ALBEDO;
        #endif
    #endif
    return directIlluminance;
}

mat3[2] sampleSkyIlluminanceComplex() {
    mat3[2] skyIlluminance = mat3[2](mat3(0.0), mat3(0.0));

    #if defined WORLD_OVERWORLD
        const ivec2 samples = ivec2(64, 32);

        for(int x = 0; x < samples.x; x++) {
            for(int y = 0; y < samples.y; y++) {
                vec3 dir        = generateUnitVector(vec2((x + 0.5) / samples.x, 0.5 * (y + 0.5) / samples.y + 0.5)).xzy; // Uniform hemisphere sampling thanks to SixthSurge#3922
                vec3 atmoSample = texture(ATMOSPHERE_BUFFER, projectSphere(dir)).rgb;

                skyIlluminance[0][0] += atmoSample * clamp01( dir.x);
                skyIlluminance[0][1] += atmoSample * clamp01( dir.y);
                skyIlluminance[0][2] += atmoSample * clamp01( dir.z);
                skyIlluminance[1][0] += atmoSample * clamp01(-dir.x);
                skyIlluminance[1][2] += atmoSample * clamp01(-dir.z);
            }
        }
        const float sampleWeight = TAU / (samples.x * samples.y);
        skyIlluminance[0][0] *= sampleWeight;
        skyIlluminance[0][1] *= sampleWeight;
        skyIlluminance[0][2] *= sampleWeight;
        skyIlluminance[1][0] *= sampleWeight;
        skyIlluminance[1][2] *= sampleWeight;

        skyIlluminance[0][0] += skyIlluminance[0][1] * 0.5;
        skyIlluminance[0][2] += skyIlluminance[0][1] * 0.5;
        skyIlluminance[1][0] += skyIlluminance[0][1] * 0.5;
        skyIlluminance[1][1] += skyIlluminance[0][1] * 0.6;
        skyIlluminance[1][2] += skyIlluminance[0][1] * 0.5;
    #endif
    return skyIlluminance;
}

vec3 getSkyLight(vec3 normal, mat3[2] skyLight) {
    vec3 octahedronPoint = normal / dot(abs(normal), vec3(1.0));
    vec3 positive = clamp01(octahedronPoint), negative = clamp01(-octahedronPoint);
    
    return skyLight[0][0] * positive.x + skyLight[0][1] * positive.y + skyLight[0][2] * positive.z
		 + skyLight[1][0] * negative.x + skyLight[1][1] * negative.y + skyLight[1][2] * negative.z;
}

vec3 sampleSkyIlluminanceSimple() {
    vec3 skyIlluminance = vec3(0.0);

    #if defined WORLD_OVERWORLD
        const ivec2 samples = ivec2(16, 8);

        for(int x = 0; x < samples.x; x++) {
            for(int y = 0; y < samples.y; y++) {
                vec3 dir        = generateUnitVector(vec2((x + 0.5) / samples.x, 0.5 * (y + 0.5) / samples.y + 0.5)).xzy; // Uniform hemisphere sampling thanks to SixthSurge#3922
                skyIlluminance += texture(ATMOSPHERE_BUFFER, projectSphere(dir)).rgb;
            }
        }
        skyIlluminance *= PI / (samples.x * samples.y);
    #endif
    return max0(skyIlluminance);
}
