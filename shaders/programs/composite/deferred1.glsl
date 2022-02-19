/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* RENDERTARGETS: 0,5 */

layout (location = 0) out vec3 color;
layout (location = 1) out vec4 historyBuffer;

#include "/include/utility/blur.glsl"
#include "/include/fragment/brdf.glsl"
#include "/include/atmospherics/celestial.glsl"
#include "/include/atmospherics/atmosphere.glsl"
#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/pathtracer.glsl"

#if GI == 1 && GI_TEMPORAL_ACCUMULATION == 1
    #include "/include/post/taa.glsl"

    void temporalAccumulation(inout vec3 color, Material mat, sampler2D prevTex, inout float historyFrames) {
        vec3 prevPos   = reprojection(vec3(texCoords, texture(depthtex0, texCoords).r));
        vec3 prevColor = texture(prevTex, prevPos.xy).rgb;

        float totalWeight = float(clamp01(prevPos.xy) == prevPos.xy);

        #if ACCUMULATION_VELOCITY_WEIGHT == 0
            vec4 weightTex     = texture(colortex10, texCoords);
            float normalWeight = pow(dot(mat.normal, weightTex.rgb), 8.0);

            float depthWeight = pow5(exp2(-abs(prevPos.z - weightTex.a)));

            totalWeight *= normalWeight * depthWeight;
        #else
            totalWeight *= 1.0 - (1.0 / max(historyFrames, 1.0));
        #endif

        color = clamp16(mix(color, prevColor, totalWeight));
    }
#endif

void main() {
    vec3 viewPos0 = getViewPos0(texCoords);

    //////////////////////////////////////////////////////////
    /*------------------------ SKY -------------------------*/
    //////////////////////////////////////////////////////////

    if(isSky(texCoords)) {
        #ifdef WORLD_OVERWORLD
            vec2 coords     = projectSphere(normalize(mat3(gbufferModelViewInverse) * viewPos0));
            vec3 starsColor = blackbody(mix(STARS_MIN_TEMP, STARS_MAX_TEMP, rand(coords)));

            vec3 sky = texture(colortex6, coords * ATMOSPHERE_RESOLUTION + (bayer2(gl_FragCoord.xy) * pixelSize)).rgb;
            color    = sky + (starfield(viewPos0) * exp(-timeMidnight) * (STARS_BRIGHTNESS * 120.0) * starsColor);
            color   += celestialBody(normalize(viewPos0));
        #else 
            color = vec3(0.0);
        #endif

        return;
    }

    //////////////////////////////////////////////////////////
    /*--------------------- MATERIAL -----------------------*/
    //////////////////////////////////////////////////////////

    Material mat        = getMaterial(texCoords);
    vec4 shadowmap      = texture(colortex3, texCoords);
    vec3 Lighting       = vec3(0.0);
    float historyFrames = 0.0;

    #if WHITE_WORLD == 1
	    mat.albedo = vec3(1.0);
        return;
    #endif

    // Overlay
    vec4 overlay = texture(colortex4, texCoords);
    mat.albedo   = mix(mat.albedo, RGBtoLinear(overlay.rgb), overlay.a);

    vec3 skyIlluminance = vec3(0.0), totalIllum = vec3(1.0);
            
    #ifdef WORLD_OVERWORLD
        skyIlluminance = texture(colortex7, texCoords).rgb;
        totalIllum     = shadowLightTransmittance();
    #else
        shadowmap.rgb = vec3(0.0);
    #endif

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
        
        color = applyLighting(viewPos0, shadowDir, mat, shadowmap, totalIllum, skyIlluminance);
    #else
        //////////////////////////////////////////////////////////
        /*------------------- PATH TRACING ---------------------*/
        //////////////////////////////////////////////////////////

        vec2 scaledUv  = texCoords * (1.0 / GI_RESOLUTION);

        if(clamp(texCoords, vec2(0.0), vec2(GI_RESOLUTION + 1e-3)) == texCoords && !isSky(scaledUv)) {
            color = pathTrace(vec3(scaledUv, texture(depthtex1, scaledUv).r), totalIllum);

            #if GI_TEMPORAL_ACCUMULATION == 1
                temporalAccumulation(color, mat, colortex5, historyFrames);
            #endif
        }
    #endif

    historyBuffer = vec4(color, historyFrames);
}
