/***********************************************/
/*       Copyright (C) Noble RT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

float computeVL(vec3 viewPos) {
    float visibility = 0.0;
    float INV_SAMPLES = 1.0 / VL_SAMPLES;

    mat4 conversion = (shadowProjection * shadowModelView) * gbufferModelViewInverse;
    vec4 startPos = conversion * vec4(vec3(0.0), 1.0);
    vec4 endPos = conversion * vec4(viewPos, 1.0);

    float jitter = fract(frameTimeCounter + bayer16(gl_FragCoord.xy));
    vec3 increment = (normalize(endPos.xyz - startPos.xyz) * distance(endPos.xyz, startPos.xyz)) * INV_SAMPLES * jitter;
    
    vec3 rayPos = startPos.xyz;
    for(int i = 0; i < VL_SAMPLES; i++) {
        rayPos += increment;
        vec3 samplePos = vec3(distort3(rayPos.xy), rayPos.z) * 0.5 + 0.5;

        visibility += texture2D(shadowtex0, samplePos.xy).r < samplePos.z ? 0.0 : 1.0;
    }
    visibility *= INV_SAMPLES;
    return visibility * VL_DENSITY;
}
