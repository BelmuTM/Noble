/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/include/fragment/brdf.glsl"
#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/shadows.glsl"
#include "/include/atmospherics/fog.glsl"

/*
const int colortex8Format = RGBA16F;
*/

void main() {
    vec3 viewPos = getViewPos(texCoords);
    material mat = getMaterial(texCoords);

    #if WHITE_WORLD == 1
	   mat.albedo = vec3(1.0);
    #endif

    vec3 volumetricLighting = VL == 0 ? vec3(0.0) : volumetricLighting(viewPos);
    vec3 Lighting = mat.albedo;
    
    #if GI == 0
        if(!isSky(texCoords)) {
            vec3 shadowmap = texture(colortex9, texCoords).rgb;

            vec3 skyIlluminance  = texture(colortex7, projectSphere(vec3(0.0, 1.0, 0.0)) * ATMOSPHERE_RESOLUTION).rgb;
            vec3 sunIlluminance  = atmosphereTransmittance(atmosRayPos, playerSunDir)  * SUN_ILLUMINANCE;
            vec3 moonIlluminance = atmosphereTransmittance(atmosRayPos, playerMoonDir) * MOON_ILLUMINANCE;
            
            Lighting = cookTorrance(viewPos, mat.normal, shadowDir, mat, shadowmap, sunIlluminance + moonIlluminance, skyIlluminance);
        }
    #endif

    /*DRAWBUFFERS:048*/
    gl_FragData[0] = vec4(Lighting,           1.0);
    gl_FragData[1] = vec4(mat.albedo,         1.0);
    gl_FragData[2] = vec4(volumetricLighting, 1.0);
}