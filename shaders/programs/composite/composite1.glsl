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
#include "/include/atmospherics/celestial.glsl"
#include "/include/atmospherics/fog.glsl"
#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/pathtracer.glsl"

#if GI_TEMPORAL_ACCUMULATION == 1
    #include "/include/post/taa.glsl"

    vec3 temporalAccumulation(sampler2D prevTex, vec3 currColor, vec3 viewPos, vec3 normal, inout float historyFrames) {
        vec2 prevTexCoords = reprojection(vec3(texCoords, texture(depthtex0, texCoords).r)).xy;
        vec3 prevColor     = texture(prevTex, prevTexCoords).rgb;

        float totalWeight = float(clamp01(prevTexCoords) == prevTexCoords);
        #if ACCUMULATION_VELOCITY_WEIGHT == 0
            vec3 prevPos    = viewToWorld(getViewPos0(prevTexCoords));
            vec3 delta      = viewToWorld(viewPos) - prevPos;
            float posWeight = max0(exp(-dot(delta, delta) * 3.0));

            float currLuma   = luminance(currColor), prevLuma = luminance(prevColor);
            float lumaWeight = exp(-(abs(currLuma - prevLuma) / max(currLuma, max(prevLuma, TAA_LUMA_MIN))));
	        lumaWeight       = mix(TAA_STRENGTH, TAA_STRENGTH, lumaWeight * lumaWeight);

            totalWeight     *= pow2(lumaWeight) * posWeight;
        #else
            historyFrames = hasMoved() ? 1.0 : texture(prevTex, texCoords).a + 1.0;
            totalWeight  *= 1.0 - (1.0 / max(historyFrames, 1.0));
        #endif

        return clamp16(mix(currColor, prevColor, totalWeight));
    }
#endif

/*DRAWBUFFERS:068*/
void main() {
    bool sky     = isSky(texCoords);
    vec3 viewPos = getViewPos0(texCoords);

    material mat = getMaterial(texCoords);
    mat.albedo   = texture(colortex4, texCoords).rgb;

    vec3 Lighting       = vec3(0.0);
    float historyFrames = texture(colortex6, texCoords).a;

    vec3 volumetricLighting = VL == 0 ? vec3(0.0) : volumetricLighting(viewPos);

    if(sky) {
        vec3 sky = vec3(0.0);

        #ifdef WORLD_OVERWORLD
            vec2 coords     = projectSphere(normalize(mat3(gbufferModelViewInverse) * viewPos));
            vec3 starsColor = blackbody(mix(STARS_MIN_TEMP, STARS_MAX_TEMP, rand(gl_FragCoord.xy)));

            vec3 tmp = texture(colortex7, coords * ATMOSPHERE_RESOLUTION + (bayer2(gl_FragCoord.xy) * pixelSize)).rgb;
            sky  = tmp + (starfield(viewPos) * exp(-timeMidnight) * (STARS_BRIGHTNESS * 200.0) * starsColor);
            sky += celestialBody(normalize(viewPos), shadowDir);
        #endif

        gl_FragData[0] = vec4(sky, 1.0);
        return;
    }
    
    #if GI == 0
        float ambientOcclusion = 1.0;
        #if AO == 1
            if(!mat.isMetal) {
                ambientOcclusion = texture(colortex9, texCoords).a;
                #if SSAO_FILTER == 1 && AO_TYPE == 0
                    ambientOcclusion = twoPassGaussianBlur(texCoords, colortex9, 1.0).a;
                #endif
            }
        #endif

        vec3 shadowmap = vec3(0.0), skyIlluminance = vec3(0.0), totalIllum = vec3(1.0);
            
        #ifdef WORLD_OVERWORLD
            shadowmap      = texture(colortex9, texCoords).rgb;
            skyIlluminance = texture(colortex8, texCoords).rgb;

            vec3 sunTransmit  = atmosphereTransmittance(atmosRayPos, playerSunDir)  * sunIlluminance;
            vec3 moonTransmit = atmosphereTransmittance(atmosRayPos, playerMoonDir) * moonIlluminance;
            totalIllum        = sunTransmit + moonTransmit;
        #endif
            
        Lighting = cookTorrance(viewPos, mat.normal, shadowDir, mat, shadowmap, totalIllum, skyIlluminance, ambientOcclusion);
    #else
        vec2 scaledUv = texCoords * (1.0 / GI_RESOLUTION);

        if(clamp(texCoords, vec2(0.0), vec2(GI_RESOLUTION + 1e-3)) == texCoords && !isSky(scaledUv)) {
            Lighting = pathTrace(vec3(scaledUv, texture(depthtex0, scaledUv).r));

            #if GI_TEMPORAL_ACCUMULATION == 1
                Lighting = temporalAccumulation(colortex6, Lighting, viewPos, mat.normal, historyFrames);
            #endif
        }
    #endif

    gl_FragData[0] = vec4(Lighting, 1.0);
    gl_FragData[1] = vec4(Lighting, historyFrames);
    gl_FragData[2] = vec4(volumetricLighting, 1.0);
}
