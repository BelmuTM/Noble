/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/bufferSettings.glsl"

#if GI == 0
    /* RENDERTARGETS: 10 */

    layout (location = 0) out vec4 aoHistory;
    
    #if AO_TYPE == 1
        #include "/include/fragment/raytracer.glsl"
        #endif
    #include "/include/fragment/ao.glsl"

    void main() {
        aoHistory = vec4(0.0, 0.0, 0.0, 1.0);

        #if AO == 1
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

                    vec3 prevPos = reprojection(vec3(scaledUv, scaledMat.depth0));
                    vec4 prevAO  = texture(colortex10, prevPos.xy);
                    float weight = clamp01(1.0 - (1.0 / max(texture(colortex5, prevPos.xy).a, 1.0)));

                    if(prevAO.a >= EPS) aoHistory.a   = mix(aoHistory.a, prevAO.a, weight);
                                        aoHistory.rgb = mix(aoHistory.rgb, prevAO.rgb, weight);
                }
            }
        #endif
    }
#else
    /* RENDERTARGETS: 10 */

    layout (location = 0) out vec4 history0;

    void main() {
        history0 = texture(colortex10, texCoords);
    }
#endif
    