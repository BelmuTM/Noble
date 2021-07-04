/***********************************************/
/*       Copyright (C) Noble SSRT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec3 computePTGI(in vec3 screenPos, in vec3 normal, vec3 shadowmap) {
    vec3 illumination = vec3(0.0);
    float jitter = bayer64(gl_FragCoord.xy);
    vec3 hitPos = screenPos;

    for(int i = 0; i < PTGI_BOUNCES; i++) {
        hitPos = screenToView(hitPos) + normal * 0.01;
        vec2 noise = hash22(gl_FragCoord.xy);
        noise = fract(frameTimeCounter + noise);

        vec3 sampleDir = randomHemisphereDirection(normal, noise.xy);
        if(!raytrace(hitPos, sampleDir, 40, jitter, hitPos)) continue;

        vec4 tex0 = texture2D(colortex0, hitPos.xy);
        vec4 tex1 = texture2D(colortex1, hitPos.xy);
        vec4 tex2 = texture2D(colortex2, hitPos.xy);
        vec4 tex3 = texture2D(colortex3, hitPos.xy);

        material data = getMaterial(tex0, tex1, tex2, tex3);
        normal = data.normal;

        vec3 BRDF = Cook_Torrance(normal, normalize(-screenToView(hitPos)), 
        sampleDir, data, vec3(0.0), vec3(0.0), vec3(0.0), false);

        illumination += BRDF * (data.emission == 0.0 ? 0.0 : 1.0);
        // (data.emission == 0.0 ? 0.0 : 1.0)
    }
    illumination *= PTGI_SCALE;
    return illumination;
}
