/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* DRAWBUFFERS:0357 */

layout (location = 0) out vec4 color;
layout (location = 1) out vec4 shadowmap;
layout (location = 2) out vec4 historyBuffer;
layout (location = 3) out vec4 volumetricLighting;

#include "/include/utility/blur.glsl"
#include "/include/fragment/brdf.glsl"
#include "/include/fragment/shadows.glsl"
#include "/include/atmospherics/celestial.glsl"
#include "/include/atmospherics/fog.glsl"
#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/pathtracer.glsl"

#if GI_TEMPORAL_ACCUMULATION == 1
    #include "/include/post/taa.glsl"

    void temporalAccumulation(sampler2D prevTex, inout vec3 color, vec3 viewPos, vec3 normal, inout float historyFrames) {
        vec2 prevTexCoords = reprojection(vec3(texCoords, texture(depthtex0, texCoords).r)).xy;
        vec3 prevColor     = texture(prevTex, prevTexCoords).rgb;

        float totalWeight = float(clamp01(prevTexCoords) == prevTexCoords);

        #if ACCUMULATION_VELOCITY_WEIGHT == 0
            totalWeight *= pow2(getLumaWeight(color, prevColor));
        #else
            historyFrames = hasMoved() ? 1.0 : texture(prevTex, texCoords).a + 1.0;
            totalWeight  *= 1.0 - (1.0 / max(historyFrames, 1.0));
        #endif

        color = clamp16(mix(color, prevColor, totalWeight));
    }
#endif

void main() {
    vec3 viewPos  = getViewPos0(texCoords);
    material mat  = getMaterial(texCoords);
    shadowmap     = texture(colortex3, texCoords);
    vec3 Lighting = vec3(0.0);

    volumetricLighting = VL == 0 ? vec4(0.0) : vec4(volumetricFog(viewPos), 1.0);

    //////////////////////////////////////////////////////////
    /*------------------------ SKY -------------------------*/
    //////////////////////////////////////////////////////////

    if(isSky(texCoords)) {
        vec3 sky = vec3(0.0);

        #ifdef WORLD_OVERWORLD
            vec2 coords     = projectSphere(normalize(mat3(gbufferModelViewInverse) * viewPos));
            vec3 starsColor = blackbody(mix(STARS_MIN_TEMP, STARS_MAX_TEMP, rand(gl_FragCoord.xy)));

            vec3 tmp = texture(colortex6, coords * ATMOSPHERE_RESOLUTION + (bayer2(gl_FragCoord.xy) * pixelSize)).rgb;
            sky      = tmp + (starfield(viewPos) * exp(-timeMidnight) * (STARS_BRIGHTNESS * 200.0) * starsColor);
            sky     += celestialBody(normalize(viewPos), shadowDir);
        #endif

        color = vec4(sky, 1.0);
        return;
    }
    
    #if GI == 0
        //////////////////////////////////////////////////////////
        /*--------------------- LIGHTING -----------------------*/
        //////////////////////////////////////////////////////////

        #if AO == 1
            if(!mat.isMetal) {
                #if SSAO_FILTER == 1 && AO_TYPE == 0
                    shadowmap.a = gaussianBlur(texCoords, colortex3, 2.2, 2.0, 4).a;
                #endif
            }
        #endif

        vec3 skyIlluminance = vec3(0.0), totalIllum = vec3(1.0);
            
        #ifdef WORLD_OVERWORLD
            skyIlluminance = texture(colortex7, texCoords).rgb;

            vec3 sunTransmit  = atmosphereTransmittance(atmosRayPos, playerSunDir)  * sunIlluminance;
            vec3 moonTransmit = atmosphereTransmittance(atmosRayPos, playerMoonDir) * moonIlluminance;
            totalIllum        = sunTransmit + moonTransmit;
        #else
            shadowmap.rgb = vec3(0.0);
        #endif
        
        color.rgb = cookTorrance(viewPos, mat.normal, shadowDir, mat, shadowmap.rgb, totalIllum, skyIlluminance, shadowmap.a);
    #else
        //////////////////////////////////////////////////////////
        /*------------------- PATH TRACING ---------------------*/
        //////////////////////////////////////////////////////////

        vec2 scaledUv       = texCoords * (1.0 / GI_RESOLUTION);
        float historyFrames = texture(colortex5, texCoords).a;

        if(clamp(texCoords, vec2(0.0), vec2(GI_RESOLUTION + 1e-3)) == texCoords && !isSky(scaledUv)) {
            color.rgb = pathTrace(vec3(scaledUv, texture(depthtex0, scaledUv).r));

            #if GI_TEMPORAL_ACCUMULATION == 1
                temporalAccumulation(colortex5, color.rgb, viewPos, mat.normal, historyFrames);
            #endif
            
            historyBuffer = vec4(color.rgb, historyFrames);
        }
    #endif
}
