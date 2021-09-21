/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#version 330 compatibility

varying vec2 texCoords;

#include "/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/fragment/bayer.glsl"
#include "/lib/fragment/noise.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/util/utils.glsl"
#include "/lib/util/worldTime.glsl"
#include "/lib/util/color.glsl"
#include "/lib/util/blur.glsl"
#include "/lib/material.glsl"
#include "/lib/lighting/brdf.glsl"
#include "/lib/atmospherics/volumetric.glsl"

/*
const int colortex8Format = RGBA16F;
*/

void main() {
    vec3 viewPos = getViewPos(texCoords);
    vec3 viewDir = normalize(-viewPos);
    vec3 lightDir = shadowLightPosition * 0.01;

    vec4 tex0 = texture2D(colortex0, texCoords);
    vec4 tex1 = texture2D(colortex1, texCoords);
    vec4 tex2 = texture2D(colortex2, texCoords);

    material data = getMaterial(tex0, tex1, tex2);
    vec3 normal = normalize(data.normal.xyz);
    
    vec3 volumetricLighting = vec3(1.0);
    #if VL == 1
        volumetricLighting = computeVL(viewPos);
    #endif

    #if WHITE_WORLD == 1
		data.albedo = vec3(1.0);
    #endif

    vec3 Lighting = tex0.rgb;
    if(!isSky(texCoords)) {
        vec3 shadowmap = texture2D(colortex9, texCoords).rgb;
        vec3 lightmapColor = vec3(1.0);
    
        #if GI == 0
            vec2 lightMap = texture2D(colortex2, texCoords).zw;
            lightmapColor = max(vec3(0.03), getLightmapColor(lightMap, getDayColor()));
        #endif

        Lighting = cookTorrance(normal, viewDir, lightDir, data, lightmapColor, shadowmap);
    }

    /*DRAWBUFFERS:048*/
    gl_FragData[0] = vec4(Lighting, 1.0);
    gl_FragData[1] = vec4(data.albedo, 1.0);
    gl_FragData[2] = vec4(volumetricLighting, 1.0);
}
