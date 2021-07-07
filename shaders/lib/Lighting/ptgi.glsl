/***********************************************/
/*       Copyright (C) Noble SSRT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec3 computePTGI(in vec3 viewPos, in vec3 normal) {
    float jitter = bayer64(gl_FragCoord.xy);
    vec3 hitPos = viewPos + normal * 0.01;

    vec3 illumination = vec3(0.0);
    vec3 weight = vec3(1.0); // How much the current iteration contributes to the final product

    for(int i = 0; i < PTGI_BOUNCES; i++) {
        if(i != 0) hitPos = screenToView(hitPos) + normal * 0.01;
        vec2 noise = texture2D(colortex8, texCoords).rg;
        //noise = fract(frameTimeCounter + noise);
        
        vec3 sampleDir = randomHemisphereDirection(normal, noise.xy);
        float NdotD = max(dot(normal, sampleDir), 0.0);
        if(NdotD < 0.0) break;

        if(!raytrace(hitPos, sampleDir, 40, jitter, hitPos)) continue;
        normal = texture2D(colortex1, hitPos.xy).rgb * 0.5 + 0.5;

        /* Thanks to Bálint#1673 and Jessie#7257 for helping me with the part below. */
        
        vec3 shadowmap = shadowMap(screenToView(hitPos), shadowMapResolution);
        vec3 albedo = texture2D(colortex0, hitPos.xy).rgb * INV_PI;
        float isEmissive = texture2D(colortex3, hitPos.xy).w == 0.0 ? 0.0 : 1.0;

        weight *= albedo * (NdotD * SUN_BRIGHTNESS);
        illumination += weight * (shadowmap + isEmissive);
    }
    return illumination;
}
