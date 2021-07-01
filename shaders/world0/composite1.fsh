/***********************************************/
/*       Copyright (C) Noble SSRT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#version 400 compatibility

varying vec2 texCoords;

#include "/settings.glsl"
#include "/lib/composite_uniforms.glsl"
#include "/lib/frag/dither.glsl"
#include "/lib/frag/noise.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/util/utils.glsl"
#include "/lib/util/gaussian.glsl"
#include "/lib/lighting/raytracer.glsl"
#include "/lib/lighting/ssgi.glsl"

void main() {
    vec4 Result = texture2D(colortex0, texCoords);

    #if VL == 1
        vec4 VolumetricLighting = texture2D(colortex4, texCoords);
        #if VL_BLUR == 1
            VolumetricLighting = fastGaussian(colortex4, vec2(viewWidth, viewHeight), 5.65, 15.0, 20.0);
        #endif

        Result += VolumetricLighting;
    #endif
    
    float Depth = texture2D(depthtex0, texCoords).r;
    if(Depth == 1.0) {
        gl_FragData[0] = Result;
        return;
    }
    vec3 viewPos = getViewPos();
    vec3 Normal = normalize(texture2D(colortex1, texCoords).rgb * 2.0 - 1.0);

    float F0 = texture2D(colortex2, texCoords).g;
    bool isMetal = (F0 * 255.0) > 229.5;

    vec3 GlobalIllumination = vec3(0.0);
    #if SSGI == 1
        GlobalIllumination = isMetal ? vec3(0.0) : computeSSGI(viewToScreen(viewPos), Normal);
    #endif

    /* DRAWBUFFERS:06 */
    gl_FragData[0] = Result;
    gl_FragData[1] = vec4(GlobalIllumination, 1.0);
}

