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
#include "/lib/fragment/bayer.glsl"
#include "/lib/fragment/noise.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/util/utils.glsl"
#include "/lib/util/color.glsl"
#include "/lib/util/worldTime.glsl"
#include "/lib/util/blur.glsl"
#include "/lib/material.glsl"
#include "/lib/lighting/brdf.glsl"
#include "/lib/util/distort.glsl"
#include "/lib/atmospherics/volumetric.glsl"

const float rainAmbientDarkness = 0.12;

/*------------------ LIGHTMAP ------------------*/
vec3 getLightmapColor(vec2 lightMap) {
    lightMap.x = TORCHLIGHT_MULTIPLIER * pow(lightMap.x, 5.06);

    vec3 torchLight = lightMap.x * TORCH_COLOR;
    vec3 skyLight = (lightMap.y * lightMap.y) * getDayTimeColor();
    return torchLight + max(vec3(EPS), skyLight - clamp(rainStrength, 0.0, rainAmbientDarkness));
}

void main() {
    vec3 viewPos = getViewPos();
    vec3 viewDir = normalize(-viewPos);
    vec3 lightDir = normalize(shadowLightPosition);

    vec4 tex0 = texture2D(colortex0, texCoords);
    vec4 tex1 = texture2D(colortex1, texCoords);
    vec4 tex2 = texture2D(colortex2, texCoords);

    material data = getMaterial(tex0, tex1, tex2);
    vec3 normal = normalize(data.normal.xyz);
    
    float volumetricLighting = 0.0;
    #if VL == 1
        volumetricLighting = clamp(computeVL(viewPos) - rainStrength, 0.0, 1.0) * 0.1;
    #endif

    if(isSky()) {
        /*DRAWBUFFERS:04*/
        gl_FragData[0] = tex0;
        gl_FragData[1] = vec4(volumetricLighting);
        return;
    }

    #if WHITE_WORLD == 1
		data.albedo = vec3(1.0);
    #endif

    vec3 shadowmap = texture2D(colortex4, texCoords).rgb;
    vec3 lightmapColor = vec3(1.0);

    vec3 globalIllumination = vec3(0.0);
    float ambientOcclusion = 1.0;
    
    #if GI == 0
        vec2 lightMap = texture2D(colortex2, texCoords).zw;
        lightmapColor = max(vec3(0.03), getLightmapColor(lightMap));

        #if AO == 1
            ambientOcclusion = texture2D(colortex5, texCoords).a;

            #if AO_FILTER == 1
                ambientOcclusion = qualityBlur(texCoords, colortex5, viewSize, 15.0, 6.0, 10.0).a;
            #endif
        #endif
    #else
        globalIllumination = clamp(texture2D(colortex6, texCoords).rgb, 0.0, 1.0);

        #if GI_FILTER == 1
            globalIllumination = spatialDenoiser(viewPos, normal, colortex6, 
            viewSize * GI_FILTER_RES, GI_FILTER_SIZE, GI_FILTER_QUALITY, 13.0).rgb;
        #endif
    #endif

    vec3 Lighting = cookTorrance(normal, viewDir, lightDir, data, lightmapColor, shadowmap, globalIllumination);

    /*DRAWBUFFERS:04*/
    gl_FragData[0] = vec4(Lighting * ambientOcclusion, 1.0);
    gl_FragData[1] = vec4(data.albedo, volumetricLighting);
}
