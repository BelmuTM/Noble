/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* RENDERTARGETS: 10 */

layout (location = 0) out vec4 ao;
    
#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/ao.glsl"

void main() {
    #if GI == 0
        ao = vec4(0.0, 0.0, 0.0, 1.0);

        #if AO == 1
            if(clamp(texCoords, vec2(0.0), vec2(AO_RESOLUTION)) == texCoords) {
                vec2 scaledUv = texCoords * rcp(AO_RESOLUTION);

                if(!isSky(scaledUv) && !isHand(scaledUv)) {
                    vec3 scaledViewPos = getViewPos0(scaledUv);
                    Material scaledMat = getMaterial(scaledUv);

                    #if AO_TYPE == 0
                        ao.a = SSAO(scaledViewPos, scaledMat.normal);
                    #elif AO_TYPE == 1
                        ao.a = RTAO(scaledViewPos, scaledMat.normal, ao.xyz);
                    #else
                        ao.a = GTAO(scaledUv, scaledViewPos, scaledMat.normal, ao.xyz);
                    #endif

                    vec3 prevPos = reprojection(vec3(scaledUv, scaledMat.depth0));
                    vec4 prevAO  = texture(colortex10, prevPos.xy);
                    float weight = clamp01(1.0 - (1.0 / max(texture(colortex5, prevPos.xy).a, 1.0)));

                    if(prevAO.a >= EPS) ao.a   = mix(ao.a, prevAO.a, weight);
                                        ao.xyz = mix(ao.xyz, prevAO.xyz, weight);
                }
            }
        #endif
    #endif
}
    