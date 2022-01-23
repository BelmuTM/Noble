/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* DRAWBUFFERS:035 */

layout (location = 0) out vec4 color;
layout (location = 1) out vec4 shadowmap;
layout (location = 2) out vec4 historyBuffer;

#include "/include/utility/blur.glsl"
#include "/include/fragment/brdf.glsl"
#include "/include/atmospherics/celestial.glsl"
#include "/include/atmospherics/atmosphere.glsl"
#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/pathtracer.glsl"
#include "/include/fragment/water.glsl"

#if GI_TEMPORAL_ACCUMULATION == 1
    #include "/include/post/taa.glsl"

    void temporalAccumulation(sampler2D prevTex, inout vec3 color, vec3 viewPos, vec3 normal, inout float historyFrames) {
        vec2 prevTexCoords = reprojection(vec3(texCoords, texture(depthtex0, texCoords).r)).xy;
        vec3 prevColor     = texture(prevTex, prevTexCoords).rgb;

        float totalWeight = float(clamp01(prevTexCoords) == prevTexCoords);

        #if ACCUMULATION_VELOCITY_WEIGHT == 0
            totalWeight *= pow2(getLumaWeight(color, prevColor));
        #else
            totalWeight *= 1.0 - (1.0 / max(historyFrames, 1.0));
        #endif

        color = clamp16(mix(color, prevColor, totalWeight));
    }
#endif

void main() {
    vec3 viewPos = getViewPos0(texCoords);

    //////////////////////////////////////////////////////////
    /*------------------------ SKY -------------------------*/
    //////////////////////////////////////////////////////////

    if(texture(depthtex1, texCoords).r == 1.0) {
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

    //////////////////////////////////////////////////////////
    /*--------------------- MATERIAL -----------------------*/
    //////////////////////////////////////////////////////////

    material mat  = getMaterial(texCoords);
    shadowmap     = texture(colortex3, texCoords);
    vec3 Lighting = vec3(0.0);

    // Rain
    mat.albedo += RGBtoLinear(texture(colortex4, texCoords).rgb);

    // Props to SixthSurge#3922 for suggesting to use depthtex2 as the caustics texture
    #if WATER_CAUSTICS == 1
        material transMat = getMaterialTranslucents(texCoords);

        bool canCast = isEyeInWater > 0.5 ? true : transMat.blockId == 1;
        if(canCast) { shadowmap.rgb *= waterCaustics(texCoords); }
    #endif

    #if WHITE_WORLD == 1
	    mat.albedo = vec3(1.0);
        return;
    #endif

    vec3 skyIlluminance = vec3(0.0), totalIllum = vec3(1.0);
            
    #ifdef WORLD_OVERWORLD
        skyIlluminance = texture(colortex7, texCoords).rgb;
        totalIllum     = shadowLightTransmittance();
    #else
        shadowmap.rgb = vec3(0.0);
    #endif

    float historyFrames = 0.0;

    #if ACCUMULATION_VELOCITY_WEIGHT == 1
        historyFrames = hasMoved() ? 1.0 : texture(colortex5, texCoords).a + 1.0;
    #endif
    
    #if GI == 0
        //////////////////////////////////////////////////////////
        /*--------------------- LIGHTING -----------------------*/
        //////////////////////////////////////////////////////////

        #if AO == 1
            if(!mat.isMetal) {
                #if SSAO_FILTER == 1 && AO_TYPE == 0
                    shadowmap.a = gaussianBlur(texCoords, colortex3, 1.4, 2.0, 4).a;
                #endif
            }
        #endif
        
        color.rgb = applyLighting(viewPos, mat, shadowmap.rgb, totalIllum, skyIlluminance, shadowmap.a, true);
    #else
        //////////////////////////////////////////////////////////
        /*------------------- PATH TRACING ---------------------*/
        //////////////////////////////////////////////////////////

        vec2 scaledUv = texCoords * (1.0 / GI_RESOLUTION);
        
        if(clamp(texCoords, vec2(0.0), vec2(GI_RESOLUTION + 1e-3)) == texCoords && !isSky(scaledUv)) {
            color.rgb = pathTrace(vec3(scaledUv, texture(depthtex0, scaledUv).r), totalIllum);

            #if GI_TEMPORAL_ACCUMULATION == 1
                temporalAccumulation(colortex5, color.rgb, viewPos, mat.normal, historyFrames);
            #endif
        }
    #endif

    historyBuffer = vec4(color.rgb, historyFrames);
}
