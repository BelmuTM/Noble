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
#include "/lib/lighting/ssao.glsl"
#include "/lib/lighting/raytracer.glsl"
#include "/lib/lighting/ptgi.glsl"

void main() {
    vec3 viewPos = getViewPos();
    vec3 Normal = normalize(texture2D(colortex1, texCoords).xyz * 2.0 - 1.0);

    vec3 GlobalIllumination = vec3(0.0);
    float AmbientOcclusion = 0.0;
    #if GI == 1
        float Depth = texture2D(depthtex0, texCoords).r;
        float F0 = texture2D(colortex2, texCoords).g;
        bool isMetal = (F0 * 255.0) > 229.5;
        
        if(!isHand(Depth)) GlobalIllumination = isMetal ? vec3(0.0) : computeGI(viewPos, Normal);
    #else
        #if SSAO == 1
            AmbientOcclusion = computeSSAO(viewPos, Normal);
        #endif
    #endif

    /*DRAWBUFFERS:5*/
    gl_FragData[0] = vec4(GlobalIllumination, AmbientOcclusion);
}

