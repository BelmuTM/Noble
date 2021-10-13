/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec3 computeVL(vec3 viewPos) {
    vec3 color = vec3(0.0);
    float INV_SAMPLES = 1.0 / VL_SAMPLES;

    vec3 startPos = projMAD3(shadowProjection, transMAD3(shadowModelView, gbufferModelViewInverse[3].xyz));
    vec3 endPos   = projMAD3(shadowProjection, transMAD3(shadowModelView, mat3(gbufferModelViewInverse) * viewPos));

    float jitter = fract(frameTimeCounter + bayer16(gl_FragCoord.xy));
    float dist   = distance(startPos, endPos);
    vec3 rayDir  = (normalize(endPos - startPos) * dist) * INV_SAMPLES * jitter;
    
    vec3 rayPos = startPos;
    for(int i = 0; i < VL_SAMPLES; i++) {
        rayPos += rayDir;
        vec3 samplePos = vec3(distort(rayPos.xy), rayPos.z) * 0.5 + 0.5;

        float shadowVisibility0 = step(samplePos.z - 1e-3, texture(shadowtex0, samplePos.xy).r);
        float shadowVisibility1 = step(samplePos.z - 1e-3, texture(shadowtex1, samplePos.xy).r);

        vec4 shadowColor      = texture(shadowcolor0, samplePos.xy);
        vec3 transmittedColor = shadowColor.rgb * (1.0 - shadowColor.a);

        // Doing both coloured VL and normal VL
        float extinction = 1.0 - exp(-dist * VL_EXTINCTION);
        color += (mix(transmittedColor * shadowVisibility1, vec3(0.0), shadowVisibility0) + shadowVisibility0) * extinction;
    }
    return color * INV_SAMPLES;
}
