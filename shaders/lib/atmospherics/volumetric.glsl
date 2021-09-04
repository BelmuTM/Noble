/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

float computeVL(vec3 viewPos) {
    float visibility = 0.0;
    float INV_SAMPLES = 1.0 / VL_SAMPLES;

    vec3 rayPos = projMAD3(shadowProjection, transMAD3(shadowModelView, gbufferModelViewInverse[3].xyz));
    vec3 endPos = projMAD3(shadowProjection, transMAD3(shadowModelView, (mat3(gbufferModelViewInverse) * viewPos)));

    float jitter = fract(frameTimeCounter + bayer64(gl_FragCoord.xy));
    vec3 rayDir = (normalize(endPos - rayPos) * distance(endPos, rayPos)) * INV_SAMPLES * jitter;
    
    for(int i = 0; i < VL_SAMPLES; i++) {
        rayPos += rayDir;
        vec3 samplePos = vec3(distort3(rayPos.xy), rayPos.z) * 0.5 + 0.5;

        visibility += texture2D(shadowtex0, samplePos.xy).r < samplePos.z ? 0.0 : 1.0;
    }
    return visibility * INV_SAMPLES;
}
