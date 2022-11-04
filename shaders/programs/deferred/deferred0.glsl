/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/bufferSettings.glsl"

/* RENDERTARGETS: 3,10 */

layout (location = 0) out vec4 shadowmap;
layout (location = 1) out vec4 aoHistory;
    
#if AO == 1
    #if AO_TYPE == 1
        #include "/include/fragment/raytracer.glsl"
    #endif
    #include "/include/fragment/ao.glsl"
#endif

#include "/include/fragment/shadows.glsl"

void main() {
    #if AO == 1 && GI == 0
        aoHistory = vec4(0.0, 0.0, 0.0, 1.0);
    #endif

    #if GI == 1
        aoHistory = texture(colortex10, texCoords);
    #endif

    #ifdef WORLD_OVERWORLD
        if(!isSky(texCoords)) {
            //////////////////////////////////////////////////////////
            /*----------------- SHADOW MAPPING ---------------------*/
            //////////////////////////////////////////////////////////
            vec3 viewPos = getViewPos0(texCoords);
            vec4 tmp     = texture(colortex2, texCoords);

            shadowmap.a    = 0.0;
            shadowmap.rgb  = shadowMap(viewToScene(viewPos), tmp.rgb, shadowmap.a);
            shadowmap.rgb *= tmp.a;
        }
    #endif

    //////////////////////////////////////////////////////////
    /*-------- AMBIENT OCCLUSION / BENT NORMALS ------------*/
    //////////////////////////////////////////////////////////

    #if AO == 1 && GI == 0
        if(clamp(texCoords, vec2(0.0), vec2(AO_RESOLUTION)) == texCoords) {
            vec2 scaledUv = texCoords * rcp(AO_RESOLUTION);

            if(!isSky(scaledUv) && !isHand(scaledUv)) {
                vec3 scaledViewPos = getViewPos0(scaledUv);
                Material scaledMat = getMaterial(scaledUv);

                #if AO_TYPE == 0
                    aoHistory.a = SSAO(scaledViewPos, scaledMat.normal);
                #elif AO_TYPE == 1
                    aoHistory.a = RTAO(scaledViewPos, scaledMat.normal, aoHistory.rgb);
                #else
                    aoHistory.a = GTAO(scaledUv, scaledViewPos, scaledMat.normal, aoHistory.rgb);
                #endif

                aoHistory.a = clamp01(aoHistory.a);

                #if AO_FILTER == 1
                    vec3 currPos = vec3(scaledUv, scaledMat.depth0);
                    vec3 prevPos = currPos - getVelocity(currPos);
                    vec4 prevAO  = texture(colortex10, prevPos.xy);
                    float weight = clamp01(1.0 - (1.0 / max(texture(colortex5, prevPos.xy).a, 1.0)));

                    aoHistory.a   = prevAO.a >= EPS ? mix(aoHistory.a, prevAO.a, weight) : aoHistory.a;
                    aoHistory.rgb = max0(mix(aoHistory.rgb, prevAO.rgb, weight));
                #else
                    aoHistory.rgb = max0(aoHistory.rgb);
                #endif
            }
        }
    #endif
}
    