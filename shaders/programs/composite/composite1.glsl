/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/include/utility/blur.glsl"
#include "/include/fragment/brdf.glsl"
#include "/include/fragment/shadows.glsl"
#include "/include/atmospherics/fog.glsl"

void main() {
    vec3 viewPos = getViewPos0(texCoords);
    material mat = getMaterial(texCoords);

    #if WHITE_WORLD == 1
	    mat.albedo = vec3(1.0);
    #endif

    vec3 volumetricLighting = VL == 0 ? vec3(0.0) : volumetricLighting(viewPos);
    vec3 Lighting = mat.albedo;
    
    #if GI == 0
        if(!isSky(texCoords)) {
            float ambientOcclusion = 1.0;
            #if AO == 1
                if(!mat.isMetal) { 
                    ambientOcclusion = SSAO_FILTER == 0 && AO_TYPE == 0 ? texture(colortex9, texCoords).a : twoPassGaussianBlur(texCoords, colortex9, 1.0).a;
                }
            #endif
            
            vec3 shadowmap      = texture(colortex9, texCoords).rgb;

            vec3 skyIlluminance = texture(colortex8, texCoords).rgb;
            vec3 sunTransmit    = atmosphereTransmittance(atmosRayPos, playerSunDir)  * sunIlluminance;
            vec3 moonTransmit   = atmosphereTransmittance(atmosRayPos, playerMoonDir) * moonIlluminance;
            
            Lighting = cookTorrance(viewPos, mat.normal, shadowDir, mat, shadowmap, sunTransmit + moonTransmit, skyIlluminance, ambientOcclusion);
        }
    #endif

    /*DRAWBUFFERS:048*/
    gl_FragData[0] = vec4(Lighting,           1.0);
    gl_FragData[1] = vec4(mat.albedo,         1.0);
    gl_FragData[2] = vec4(volumetricLighting, 1.0);
}
