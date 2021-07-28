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

    vec3 normal = normalize(decodeNormal(texture2D(colortex1, hitPos.xy).xy));
    vec3 tangent = normalize(cross(gbufferModelView[1].xyz, normal));
    mat3 TBN = mat3(tangent, cross(normal, tangent), normal); 

    for(int i = 0; i < GI_BOUNCES; i++) {
        /* Updating positions for the next bounce */
        normal = normalize(decodeNormal(texture2D(colortex1, hitPos.xy).xy));
        hitPos = screenToView(hitPos) + normal * EPS;
        
        vec2 noise = uniformAnimatedNoise();
        vec3 sampleDir = randomHemisphereDirection(noise.xy);
        sampleDir = TBN * sampleDir;
        bool hit = raytrace(hitPos, sampleDir, int(29.3 * pow(0.78, GI_BOUNCES)), noise.x, hitPos);

        if(hit) {
            /* Thanks to Bálint#1673 and Jessie#7257 for helping me with the part below. */
            vec3 shadowmap = texture2D(colortex7, hitPos.xy).rgb;
            vec3 albedo = texture2D(colortex0, hitPos.xy).rgb;
            float isEmissive = texture2D(colortex1, hitPos.xy).z == 0.0 ? 0.0 : 1.0;

            weight *= albedo;
            illumination += weight * (shadowmap + isEmissive);
        }
    }
    return illumination;
}
