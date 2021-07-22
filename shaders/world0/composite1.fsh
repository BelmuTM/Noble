/***********************************************/
/*       Copyright (C) Noble RT - 2021       */
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
#include "/lib/util/worldTime.glsl"
#include "/lib/lighting/ssao.glsl"
#include "/lib/lighting/raytracer.glsl"
#include "/lib/lighting/ptgi.glsl"

void main() {
    vec3 viewPos = getViewPos();
    vec3 normal = normalize(texture2D(colortex1, texCoords).xyz * 2.0 - 1.0);

    vec3 GlobalIllumination = vec3(0.0);
    float AmbientOcclusion = 1.0;
    #if GI == 1
        /* Downscaling Global Illumination */
        float inverseRes = 1.0 / GI_RESOLUTION;
        vec2 scaledUv = texCoords * inverseRes;

        float depth = texture2D(depthtex0, scaledUv).r;
        
        if(!isHand(depth) && clamp(texCoords, vec2(0.0), vec2(GI_RESOLUTION)) == texCoords) {
            float F0 = texture2D(colortex2, scaledUv).g;
            bool isMetal = (F0 * 255.0) > 229.5;

            vec3 positionAt = vec3(scaledUv, texture2D(depthtex0, scaledUv).r);
            GlobalIllumination = isMetal ? vec3(0.0) : computeGI(positionAt);
        }
    #else
        #if SSAO == 1
            AmbientOcclusion = computeSSAO(viewPos, normal);
        #endif
    #endif

    /*DRAWBUFFERS:5*/
    gl_FragData[0] = vec4(GlobalIllumination, AmbientOcclusion);
}

