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
        vec2 noise = hash22(gl_FragCoord.xy);
        noise = fract(frameTimeCounter + noise);

        vec3 sampleDir = randomHemisphereDirection(normal, noise.xy);
        if(!raytrace(hitPos, sampleDir, 40, jitter, hitPos)) continue;

        vec4 tex0 = texture2D(colortex0, hitPos.xy);
        vec4 tex1 = texture2D(colortex1, hitPos.xy);
        vec4 tex2 = texture2D(colortex2, hitPos.xy);
        vec4 tex3 = texture2D(colortex3, hitPos.xy);

        material data = getMaterial(tex0, tex1, tex2, tex3);
        normal = data.normal * 0.5 + 0.5;

        vec3 BRDF = Cook_Torrance(normal, normalize(-screenToView(hitPos)), 
        sampleDir, data, vec3(0.0), vec3(0.0), vec3(0.0), true);

        /* Thanks to Bálint#1673 and Jessie#7257 for helping me with the part below. */
        vec3 shadowmap = shadowMap(screenToView(hitPos), shadowMapResolution);
        
        weight *= BRDF;
        illumination += weight * (shadowmap + (data.emission == 0 ? 0.0 : 1.0));
        // (data.emission == 0 ? 0.0 : 1.0)
    }
    illumination *= PTGI_SCALE;
    return illumination;
}
