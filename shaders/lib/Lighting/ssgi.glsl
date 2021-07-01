/***********************************************/
/*       Copyright (C) Noble SSRT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec3 computeSSGI(in vec3 screenPos, in vec3 normal) {
    vec3 illumination = vec3(0.0);
    float jitter = bayer64(gl_FragCoord.xy);

    vec3 hitPos = screenPos;
    for(int i = 0; i < SSGI_BOUNCES; i++) {
        //vec3 sampleOrigin = screenToView(hitPos) + normal * 0.01;

        for(int j = 0; j < SSGI_SAMPLES; j++) {
            hitPos = screenToView(hitPos);
            vec3 noise = hash33(vec3(gl_FragCoord.xy, j));
            noise = fract(vec3(frameTimeCounter) + noise);

            //Sampling pos
            vec3 sampleDir = randomHemisphereDirection(normal, noise.xy);
            float NdotD = max(dot(normal, sampleDir), 0.0);
            float PDF = NdotD * INV_PI;

            // Ray trace
            if(!raytrace(hitPos, sampleDir, 25, jitter, hitPos)) continue;
            normal = texture2D(colortex1, hitPos.xy).xyz;

            vec3 sampleColor = texture2D(colortex0, hitPos.xy).rgb;
            illumination += sampleColor * NdotD / PDF;
        }
        illumination /= SSGI_SAMPLES;
    }
    illumination *= SSGI_SCALE;
    return illumination;
}
