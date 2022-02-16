/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec3 cloudsScattering(vec3 rayDir) {
    vec2 dists = intersectSphericalShell(atmosRayPos, rayDir, innerCloudRad, outerCloudRad);
    if(dists.y < 0.0) return vec3(0.0);

    float stepLength = (dists.y - dists.x) / float(CLOUDS_STEPS);
    vec3 increment   = rayDir * stepLength;
    vec3 rayPos      = atmosRayPos + rayDir * (dists.x + bayer2(gl_FragCoord.xy) * stepLength);

    vec3 scattering = vec3(0.0); float transmittance = 1.0;
    
    for(int i = 0; i < CLOUDS_STEPS; i++, rayPos += increment) {

    }
    return scattering;
}