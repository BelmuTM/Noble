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
#include "/lib/uniforms.glsl"
#include "/lib/fragment/noise.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/util/utils.glsl"
#include "/lib/util/worldTime.glsl"
#include "/lib/util/blur.glsl"
#include "/lib/material.glsl"
#include "/lib/lighting/brdf.glsl"
#include "/lib/lighting/raytracer.glsl"
#include "/lib/lighting/ssr.glsl"
#include "/lib/post/bloom.glsl"

void main() {
    vec4 Result = texture2D(colortex0, texCoords);

    float volumetricLighting = texture2D(colortex4, texCoords).a;
    #if VL == 1
        #if VL_FILTER == 1
            volumetricLighting = bilateralBlur(texCoords, colortex4, 5).a;
        #endif
    #endif

    if(isSky()) {
        gl_FragData[0] = Result;
        return;
    }

    #if SSR == 1
        vec3 viewPos = getViewPos();
        vec3 normal = normalize(decodeNormal(texture2D(colortex1, texCoords).xy));

        float NdotV = saturate(dot(normal, normalize(-viewPos)));
        float F0 = texture2D(colortex2, texCoords).g;

        vec3 specColor = (F0 * 255.0) > 229.5 ? texture2D(colortex4, texCoords).rgb : vec3(F0);
        float roughness = hardCodedRoughness != 0.0 ? hardCodedRoughness : texture2D(colortex2, texCoords).r;

        vec3 reflections;
        #if SSR_TYPE == 1
            reflections = prefilteredReflections(viewPos, normal, roughness);
        #else
            reflections = simpleReflections(viewPos, normal, NdotV, specColor);
        #endif

        vec3 DFG = envBRDFApprox(specColor, roughness, NdotV);
        Result.rgb += mix(Result.rgb, reflections, DFG);
    #endif

    Result.rgb += getDayTimeColor() * volumetricLighting;

    /*DRAWBUFFERS:0*/
    gl_FragData[0] = Result;
}
