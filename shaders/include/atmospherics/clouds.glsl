/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

float getCloudsDensity(vec2 pos, float cloudAltitude) {
    return rand(pos);
}

float getCloudsOpticalDepth(vec3 rayOrigin, vec3 lightDir, int stepCount) {
    float stepLength = intersectSphericalShell(rayOrigin, lightDir, innerCloudRad, outerCloudRad).y / float(stepCount);
    vec3 increment   = lightDir * stepLength;
    vec3 rayPos      = rayOrigin + increment * 0.5;

    float accumAirmass = 0.0;
    for(int i = 0; i < stepCount; i++, rayPos += increment) {
        float cloudAltitude = (length(rayPos) - innerCloudRad) / CLOUDS_THICKNESS;
              accumAirmass += getCloudsDensity(rayPos, cloudAltitude) * stepLength;
    }

    return accumAirmass;
}

vec3 cloudsScattering(vec3 rayDir) {
    vec2 dists = intersectSphericalShell(atmosRayPos, rayDir, innerCloudRad, outerCloudRad);
    if(dists.y < 0.0) return vec3(0.0);

    float stepLength = (dists.y - dists.x) / float(CLOUDS_STEPS);
    vec3 increment   = rayDir * stepLength;
    vec3 rayPos      = atmosRayPos + rayDir * 0.5;

    float scattering = 0.0, transmittance = 1.0;
    
    for(int i = 0; i < CLOUDS_STEPS; i++, rayPos += increment) {

        float cloudAltitude   = (length(rayPos) - innerCloudRad) / CLOUDS_THICKNESS;
        vec3 stepOpticalDepth = 0.08 * getCloudsDensity(length(rayPos)) * stepLength;

        vec3 stepTransmittance  = exp(-stepOpticalDepth);
        vec3 scatteringIntegral = clamp01((stepTransmittance - 1.0) / -stepOpticalDepth);

        float opticalDepth     = getCloudsOpticalDepth(rayPos, sceneShadowDir, 6);
        vec3 anisotropyFactors = pow(vec3(0.45, 0.35, 0.95), vec3(1.0 + opticalDepth));

        float stepScattering = 0.0;

        for(int i = 0; i < 6; i++) {
            float forwardsLobe  = henyeyGreensteinPhase(cosTheta, anisotropyFactors.x);
	        float backwardsLobe = henyeyGreensteinPhase(cosTheta, anisotropyFactors.y);
	        float forwardsPeak  = henyeyGreensteinPhase(cosTheta, anisotropyFactors.z);

        }

        scattering    += stepScattering * (scatteringIntegral * transmittance);
        transmittance *= stepTransmittance;
    }
    return vec3(scattering);
}