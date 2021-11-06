#version 400 compatibility
#include "/programs/extensions.glsl"

/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

varying vec2 texCoords;

#include "/settings.glsl"
#include "/programs/common.glsl"

#include "/lib/fragment/brdf.glsl"
#include "/lib/fragment/raytracer.glsl"
#include "/lib/fragment/shadows.glsl"

#include "/lib/atmospherics/atmosphere.glsl"
#include "/lib/atmospherics/volumetric.glsl"

/*
const int colortex8Format = RGBA16F;
*/

void main() {
    vec3 viewPos = getViewPos(texCoords);
    material mat = getMaterial(texCoords);
    
    vec3 volumetricLighting = vec3(1.0);
    #if VL == 1
        volumetricLighting = computeVL1(viewPos);
    #endif

    #if WHITE_WORLD == 1
		mat.albedo = vec3(1.0);
    #endif

    vec3 Lighting = mat.albedo;
    #if GI == 0
        if(!isSky(texCoords)) {
            vec3 normal = normalize(mat.normal.xyz);
            vec3 shadowmap = texture(colortex9, texCoords).rgb;

            vec3 skyIlluminance = atmosphereTransmittance(atmosRayPos, vec3(0.0, 1.0, 0.0));
            vec3 sunIlluminance = SUN_ILLUMINANCE * atmosphereTransmittance(atmosRayPos, worldSunDir);
            vec3 moonIlluminance = MOON_ILLUMINANCE * atmosphereTransmittance(atmosRayPos, worldMoonDir);
            
            vec3 lightmap = getLightmapColor(texture(colortex2, texCoords).zw, skyIlluminance);
            Lighting = cookTorrance(viewPos, normal, shadowDir, mat, lightmap, shadowmap, sunIlluminance + moonIlluminance);
        }
    #endif

    /*DRAWBUFFERS:048*/
    gl_FragData[0] = vec4(max(vec3(0.0), Lighting), 1.0);
    gl_FragData[1] = vec4(mat.albedo, 1.0);
    gl_FragData[2] = vec4(volumetricLighting, 1.0);
}
