/***********************************************/
/*       Copyright (C) Noble SSRT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#version 400 compatibility

varying vec2 texCoords;

uniform vec3 previousCameraPosition;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;

#include "/settings.glsl"
#include "/lib/composite_uniforms.glsl"
#include "/lib/frag/dither.glsl"
#include "/lib/frag/noise.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/util/utils.glsl"
#include "/lib/util/worldTime.glsl"
#include "/lib/util/blur.glsl"
#include "/lib/util/reprojection.glsl"
#include "/lib/lighting/raytracer.glsl"
#include "/lib/lighting/ssr.glsl"

// https://www.unrealengine.com/en-US/blog/physically-based-shading-on-mobile?sessionInvalidated=true
vec3 Env_BRDF_Approx(vec3 specular, float NdotV, float roughness) {
    const vec4 c0 = vec4(-1.0, -0.0275, -0.572, 0.022);
    const vec4 c1 = vec4(1.0, 0.0425, 1.04, -0.04);
    vec4 r = roughness * c0 + c1;
    float a004 = min(r.x * r.x, exp2(-9.28 * NdotV)) * r.x + r.y;
    vec2 AB = vec2(-1.04, 1.04) * a004 + r.zw;
    return specular * AB.x + AB.y;
}

void main() {
    vec4 Result = texture2D(colortex0, texCoords);

    #if VL == 1
        float VolumetricLighting = texture2D(colortex4, texCoords).r;
        #if VL_BLUR == 1
            /* HIGH QUALITY - MORE EXPENSIVE */
            //VolumetricLighting = fastGaussian(colortex4, vec2(viewWidth, viewHeight), 5.65, 15.0, 20.0).r;

            /* DECENT QUALITY - LESS EXPENSIVE */
            VolumetricLighting = bilateralBlur(colortex4).r;
        #endif

        Result.rgb += vec3(getDayTimeSunColor() * VolumetricLighting);
    #endif

    float Depth = texture2D(depthtex0, texCoords).r;
    if(texture2D(colortex8, texCoords).r != 0.0 || Depth == 1.0) {
        gl_FragData[0] = Result;
        return;
    }

    #if SSR == 1
        vec3 viewPos = getViewPos();
        vec3 Normal = normalize(texture2D(colortex1, texCoords).rgb * 2.0 - 1.0);
        float NdotV = max(dot(Normal, normalize(-viewPos)), 0.0);
        
        float F0 = texture2D(colortex2, texCoords).g;
        bool isMetal = (F0 * 255.0) > 229.5;
        vec3 specColor = isMetal ? texture2D(colortex5, texCoords).rgb : vec3(F0);

        #if SSR_TYPE == 1
            float roughness = texture2D(colortex2, texCoords).r;

            vec3 reflections = prefilteredReflections(viewPos, Normal, roughness);
            vec3 DFG = Env_BRDF_Approx(specColor, roughness, NdotV);
            Result.rgb = mix(Result.rgb, reflections, DFG);
        #else
            Result.rgb += simpleReflections(Result.rgb, viewPos, Normal, NdotV, specColor);
        #endif
    #endif

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = Result;
}
