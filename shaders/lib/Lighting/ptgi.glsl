/***********************************************/
/*       Copyright (C) Noble RT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec3 computePTGI(in vec3 screenPos) {
    vec3 hitPos = screenPos;
    vec3 illumination = vec3(0.0);
    vec3 weight = vec3(1.0);

    vec2 noise = uniformAnimatedNoise();
    vec3 dayTimeColor = getDayTimeColor();

    for(int i = 0; i < GI_BOUNCES; i++) {
        noise = uniformIndexedNoise(i, noise);

        /* Updating our position for the next bounce */
        vec3 normal = normalize(decodeNormal(texture2D(colortex1, hitPos.xy).xy));
        hitPos = screenToView(hitPos) + normal * EPS;
        
        vec3 sampleDir = tangentToWorld(normal, randomHemisphereDirection(noise));
        if(!raytrace(hitPos, sampleDir, GI_STEPS, blueNoise().r, hitPos)) continue;

        /* Thanks to Bálint#1673 and Jessie#7257 for helping me with the part below. */
        vec3 shadowmap = texture2D(colortex4, hitPos.xy).rgb;
        vec3 albedo = texture2D(colortex0, hitPos.xy).rgb;
        float isEmissive = texture2D(colortex1, hitPos.xy).z == 0.0 ? 0.0 : 1.0;

        weight *= albedo;
        illumination += weight * (shadowmap + isEmissive);
    }
    return illumination;
}
