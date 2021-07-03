/***********************************************/
/*       Copyright (C) Noble SSRT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec3 computeSSGI(in vec3 screenPos, in vec3 normal, in vec3 lightDir, in vec3 shadowmap) {
    vec3 illumination = vec3(0.0);
    float jitter = bayer64(gl_FragCoord.xy);
    vec3 hitPos = screenPos;

    for(int i = 0; i < SSGI_BOUNCES; i++) {
        hitPos = screenToView(hitPos) + normal * 0.01;
        vec2 noise = hash22(gl_FragCoord.xy);
        noise = fract(frameTimeCounter + noise);

        vec3 sampleDir = randomHemisphereDirection(normal, noise.xy);
        if(!raytrace(hitPos, sampleDir, 48, jitter, hitPos)) continue;

        vec4 tex0 = texture2D(colortex0, hitPos.xy);
        vec4 tex1 = texture2D(colortex1, hitPos.xy);
        vec4 tex2 = texture2D(colortex2, hitPos.xy);
        vec4 tex3 = texture2D(colortex3, hitPos.xy);

        normal = tex1.xyz;
        material data = getMaterial(tex0, tex1, tex2, tex3);
        vec3 BRDF = Cook_Torrance(normal, normalize(-hitPos), lightDir, data, AMBIENT, shadowmap);
        illumination += BRDF;
    }
    illumination *= SSGI_SCALE;
    return illumination;
}
