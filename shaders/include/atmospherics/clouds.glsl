/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

float getCloudsDensity(vec3 rayPos) {
    float cloudAltitude = (length(rayPos) - innerCloudRad) / CLOUDS_THICKNESS;
    return FBM(rayPos.xy, 4);
}

float getCloudsTransmittance(vec3 rayPos, vec3 lightDir, int stepCount) {
    float stepLength = 25.0, transmittance = 0.0;

    for(int i = 0; i < stepCount; i++, rayPos += lightDir * stepLength) {
        transmittance += getCloudsDensity(rayPos) * stepLength;
        stepLength    *= 1.5;
    }
    return transmittance;
}

vec4 cloudsScattering(vec3 rayDir) {
    vec2 dists = intersectSphericalShell(atmosRayPos, rayDir, innerCloudRad, outerCloudRad);
    if(dists.y < 0.0) return vec4(0.0);

    float stepLength = (dists.y - dists.x) / float(CLOUDS_STEPS);
    vec3 increment   = rayDir * stepLength;
    vec3 rayPos      = atmosRayPos + rayDir * 0.5;

    float LdotV   = dot(rayDir, sceneShadowDir);
    const vec3 up = vec3(0.0, 1.0, 0.0);

    vec3 scattering = vec3(0.0); float transmittance = 1.0;
    
    for(int i = 0; i < CLOUDS_STEPS; i++, rayPos += increment) {
        float opticalDepth = getCloudsDensity(rayPos) * stepLength;
        if(opticalDepth <= 0.0) continue;

        float stepTransmittance  = exp(-opticalDepth);
        float scatteringIntegral = clamp01((stepTransmittance - 1.0) / -opticalDepth);

        float directTransmittance   = getCloudsTransmittance(rayPos, sceneShadowDir, 16);
        float indirectTransmittance = getCloudsTransmittance(rayPos, up,              8);

        //vec3 anisotropyFactors = pow(vec3(0.45, 0.35, 0.95), vec3(1.0 + opticalDepth));

        for(int j = 0; j < 6; j++) {
            //float forwardsLobe  = henyeyGreensteinPhase(LdotV, anisotropyFactors.x);
	        //float backwardsLobe = henyeyGreensteinPhase(LdotV, anisotropyFactors.y);
	        //float forwardsPeak  = henyeyGreensteinPhase(LdotV, anisotropyFactors.z);

            // How to calculate scattering here ??
        }

        transmittance *= stepTransmittance;
    }

    scattering += scattering.x * sampleDirectIlluminance();
    scattering += scattering.y * texture(colortex6, texCoords).rgb;

    return vec4(scattering, transmittance);
}
