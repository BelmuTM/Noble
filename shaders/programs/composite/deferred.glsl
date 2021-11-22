/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/fragmentSettings.glsl"
#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/shadows.glsl"
#include "/include/atmospherics/atmosphere.glsl"

void main() {
    vec3 shadowmap = vec3(0.0);
    vec3 sky       = vec3(0.0);

    #if WORLD == OVERWORLD
        /*    ------- SHADOW MAPPING -------    */
        #if SHADOWS == 1
            shadowmap = shadowMap(getViewPos(texCoords));
        #endif

        /*    ------- ATMOSPHERIC SCATTERING -------    */
        if(clamp(texCoords, vec2(0.0), vec2(ATMOSPHERE_RESOLUTION + 1e-2)) == texCoords) {
            vec3 rayDir = unprojectSphere(texCoords * (1.0 / ATMOSPHERE_RESOLUTION));
            sky = atmosphericScattering(atmosRayPos, rayDir);
        }
    #endif

    /*DRAWBUFFERS:479*/
    gl_FragData[0] = sRGBToLinear(texture(colortex0, texCoords));
    gl_FragData[1] = vec4(sky, 1.0);
    gl_FragData[2] = vec4(shadowmap, 1.0);
}
