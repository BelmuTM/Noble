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
#include "/common.glsl"
#include "/lib/util/blur.glsl"
#include "/lib/fragment/brdf.glsl"
#include "/lib/atmospherics/volumetric.glsl"

/*
const int colortex8Format = RGBA16F;
*/

void main() {
    vec3 viewPos = getViewPos(texCoords);
    vec3 viewDir = normalize(-viewPos);

    vec4 tex0 = texture(colortex0, texCoords);
    vec4 tex1 = texture(colortex1, texCoords);
    vec4 tex2 = texture(colortex2, texCoords);

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
        vec3 shadowmap = texture(colortex9, texCoords).rgb;
        vec3 lightmapColor = vec3(1.0);
    
        #if GI == 0
            vec2 lightMap = texture(colortex2, texCoords).zw;
            lightmapColor = max(vec3(0.03), getLightmapColor(lightMap, viewPosSkyColor(viewPos)));
        #endif

        Lighting = cookTorrance(viewPos, normal, viewDir, sunDir, data, lightmapColor, shadowmap);
    }

    /*DRAWBUFFERS:048*/
    gl_FragData[0] = vec4(Lighting, 1.0);
    gl_FragData[1] = vec4(data.albedo, 1.0);
    gl_FragData[2] = vec4(volumetricLighting, 1.0);
}
