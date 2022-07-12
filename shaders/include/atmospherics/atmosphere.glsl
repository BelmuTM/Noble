/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/*
    SOURCES / CREDITS:
    Thanks LVutner#5199 and Jessie#7257 for the help!

    ScratchaPixel:   https://www.scratchapixel.com/lessons/procedural-generation-virtual-worlds/simulating-sky/simulating-colors-of-the-sky
    Wikipedia:       https://fr.wikipedia.org/wiki/Th%C3%A9orie_de_Mie
    Sebastian Lague: https://www.youtube.com/watch?v=DxfEbulyFcY
    LVutner:         https://github.com/LVutner
    gltracy:         https://www.shadertoy.com/view/lslXDr
*/

vec3 getAtmosDensities(float centerDist) {
	float altitudeKm = (centerDist - earthRad) * 1e-3;
	vec2 rayleighMie = exp(altitudeKm / -(scaleHeights * 1e-3));

    // Ozone approximation from Jessie#7257
    float o1 = 25.0 *     exp(( 0.0 - altitudeKm) /   8.0);
    float o2 = 30.0 * pow(exp((18.0 - altitudeKm) /  80.0), altitudeKm - 18.0);
    float o3 = 75.0 * pow(exp((25.3 - altitudeKm) /  35.0), altitudeKm - 25.3);
    float o4 = 50.0 * pow(exp((30.0 - altitudeKm) / 150.0), altitudeKm - 30.0);
    float ozone = (o1 + o2 + o3 + o4) / 134.628;

	return vec3(rayleighMie, ozone);
}

vec3 atmosphereTransmittance(vec3 rayOrigin, vec3 lightDir) {
    float stepLength = intersectSphere(rayOrigin, lightDir, atmosUpperRad).y * rcp(TRANSMITTANCE_STEPS);
    vec3 increment   = lightDir * stepLength;
    vec3 rayPos      = rayOrigin + increment * 0.5;

    vec3 accumAirmass = vec3(0.0);
    for(int i = 0; i < TRANSMITTANCE_STEPS; i++, rayPos += increment) {
        accumAirmass += getAtmosDensities(fastLength(rayPos)) * stepLength;
    }
    return exp(-atmosExtinctionCoeff * accumAirmass);
}

#if defined STAGE_FRAGMENT
    vec3 atmosphericScattering(vec3 rayDir, vec3 skyIlluminance) {
        vec2 dists = intersectSphericalShell(atmosRayPos, rayDir, atmosLowerRad, atmosUpperRad);
        if(dists.y < 0.0) return vec3(0.0);

        float stepLength = (dists.y - dists.x) * rcp(SCATTERING_STEPS);
        vec3 increment   = rayDir * stepLength;
        vec3 rayPos      = atmosRayPos + increment * 0.5;

        vec2 VdotL    = vec2(dot(rayDir, sceneSunDir), dot(rayDir, sceneMoonDir));
        vec2 phase[2] = vec2[2](
            vec2(rayleighPhase(VdotL.x), kleinNishinaPhase(VdotL.x, atmosEnergyParam)), 
            vec2(rayleighPhase(VdotL.y), kleinNishinaPhase(VdotL.y, atmosEnergyParam))
        );

        mat2x3 singleScattering = mat2x3(vec3(0.0), vec3(0.0)); vec3 multipleScattering = vec3(0.0); vec3 transmittance = vec3(1.0);
    
        for(int i = 0; i < SCATTERING_STEPS; i++, rayPos += increment) {
            vec3 airmass          = getAtmosDensities(fastLength(rayPos)) * stepLength;
            vec3 stepOpticalDepth = atmosExtinctionCoeff * airmass;

            vec3 stepTransmittance  = exp(-stepOpticalDepth);
            vec3 visibleScattering  = transmittance * clamp01((stepTransmittance - 1.0) / -stepOpticalDepth);
            vec3 sunStepScattering  = atmosScatteringCoeff * (airmass.xy * phase[0]) * visibleScattering;
            vec3 moonStepScattering = atmosScatteringCoeff * (airmass.xy * phase[1]) * visibleScattering;

            singleScattering[0] += sunStepScattering  * atmosphereTransmittance(rayPos, sceneSunDir);
            singleScattering[1] += moonStepScattering * atmosphereTransmittance(rayPos, sceneMoonDir);

            vec3 stepScattering    = atmosScatteringCoeff * airmass.xy;
            vec3 stepScatterAlbedo = stepScattering / stepOpticalDepth;

            vec3 multScatteringFactor = stepScatterAlbedo * 0.84;
            vec3 multScatteringEnergy = multScatteringFactor * rcp(1.0 - multScatteringFactor);
                 multipleScattering  += multScatteringEnergy * visibleScattering * stepScattering;

            transmittance *= stepTransmittance;
        }
        multipleScattering  *= (skyIlluminance * INV_PI) * isotropicPhase;
        singleScattering[0] *= sunIlluminance;
        singleScattering[1] *= moonIlluminance;
    
        return singleScattering[0] + singleScattering[1] + multipleScattering;
    }
#endif

vec3 sampleDirectIlluminance() {
    vec3 directIlluminance = vec3(0.0);

    #ifdef WORLD_OVERWORLD
        vec3 sunTransmit  = atmosphereTransmittance(atmosRayPos, sceneSunDir)  * sunIlluminance;
        vec3 moonTransmit = atmosphereTransmittance(atmosRayPos, sceneMoonDir) * moonIlluminance;
        directIlluminance = sunTransmit + moonTransmit;

        #if TONEMAP == 0
            directIlluminance *= sRGB_2_AP1_ALBEDO;
        #endif
    #endif
    return directIlluminance;
}

mat3[2] sampleSkyIlluminance(inout vec3 skyMultScatterIllum) {
    mat3[2] skyIllum    = mat3[2](mat3(0.0), mat3(0.0));
    skyMultScatterIllum = vec3(0.0);

    #ifdef WORLD_OVERWORLD
        const ivec2 samples = ivec2(16, 8);

        for(int x = 0; x < samples.x; x++) {
            for(int y = 0; y < samples.y; y++) {
                vec3 dir        = generateUnitVector(vec2((x + 0.5) / samples.x, 0.5 * (y + 0.5) / samples.y + 0.5)).xzy; // Uniform hemisphere sampling thanks to SixthSurge#3922
                vec3 atmoSample = texture(colortex0, projectSphere(dir) * ATMOSPHERE_RESOLUTION).rgb;

                skyIllum[0][0] += atmoSample * clamp01(dir.x);
                skyIllum[0][1] += atmoSample * clamp01(dir.y);
                skyIllum[0][2] += atmoSample * clamp01(dir.z);
                skyIllum[1][0] += atmoSample * clamp01(-dir.x);
                skyIllum[1][2] += atmoSample * clamp01(-dir.z);

                skyMultScatterIllum += atmoSample;
            }
        }
        const float sampleWeight = 2.0 * TAU / (samples.x * samples.y);
        skyIllum[0][0] *= sampleWeight;
        skyIllum[0][1] *= sampleWeight;
        skyIllum[0][2] *= sampleWeight;
        skyIllum[1][0] *= sampleWeight;
        skyIllum[1][2] *= sampleWeight;

        skyIllum[0][0] += skyIllum[0][1] * 0.14;
        skyIllum[0][2] += skyIllum[0][1] * 0.14;
        skyIllum[1][0] += skyIllum[0][1] * 0.14;
        skyIllum[1][1] += skyIllum[0][1] * 0.14;
        skyIllum[1][2] += skyIllum[0][1] * 0.14;

        skyMultScatterIllum *= (TAU / (samples.x * samples.y));
    #endif
    return skyIllum;
}

vec3 getSkyLight(vec3 normal, mat3[2] skyLight) {
    vec3 octahedronPoint = normal / dot(abs(normal), vec3(1.0));
    vec3 positive = clamp01(octahedronPoint), negative = clamp01(-octahedronPoint);
    
    return skyLight[0][0] * positive.x + skyLight[0][1] * positive.y + skyLight[0][2] * positive.z
		 + skyLight[1][0] * negative.x + skyLight[1][1] * negative.y + skyLight[1][2] * negative.z;
}
