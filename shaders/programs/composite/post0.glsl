/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/include/utility/blur.glsl"
#include "/include/post/bloom.glsl"
#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/shadows.glsl"
#include "/include/atmospherics/fog.glsl"

void main() {
    vec4 color = pow2(texture(colortex0, texCoords));

    vec4 bloom = vec4(0.0);
    #if BLOOM == 1
        bloom = writeBloom();
    #endif
     
    #if RAIN_FOG == 1
        if(rainStrength > 0.0) {
            vec3 viewPos = getViewPos0(texCoords);
            vec3 sky     = texture(colortex7, projectSphere(vec3(0.0, 1.0, 0.0)) * ATMOSPHERE_RESOLUTION).rgb;

            color.rgb   += groundFog(viewPos, color.rgb, sky * 0.1, rainStrength, 1.0);
        }
    #endif

    /*DRAWBUFFERS:05*/
    gl_FragData[0] = color;
    gl_FragData[1] = bloom;
}
