/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/include/common.glsl"
#include "/internalSettings.glsl"

/* RENDERTARGETS: 10 */

layout (location = 0) out vec4 ao;
    
#if AO == 1
    #if AO_TYPE == 1
        #include "/include/fragment/raytracer.glsl"
    #endif
    #include "/include/fragment/ao.glsl"
#endif

void main() {
    #if AO == 1 && GI == 0
        ao = vec4(0.0, 0.0, 0.0, 1.0);
    #else
        #if GI == 1
            ao = texture(INDIRECT_BUFFER, texCoords);
        #endif
        return;
    #endif

    if(isSky(texCoords) || isHand(texCoords)) return;

    #if AO == 1
        vec3 viewPos = getViewPos0(texCoords);
        Material material = getMaterial(texCoords);

        #if AO_TYPE == 0
            ao.w = SSAO(viewPos, material.normal);
        #elif AO_TYPE == 1
            ao.w = RTAO(viewPos, material.normal, ao.xyz);
        #elif AO_TYPE == 2
            ao.w = GTAO(texCoords, viewPos, material.normal, ao.xyz);
        #endif

        ao.w = clamp01(ao.w);

        #if AO_FILTER == 1
            vec3 currPos = vec3(texCoords, material.depth0);
            vec3 prevPos = currPos - getVelocity(currPos);
            vec4 prevAO  = texture(INDIRECT_BUFFER, prevPos.xy);
        
            float weight = 1.0 / max(texture(DEFERRED_BUFFER, prevPos.xy).w, 1.0);

            ao.w   = mix(prevAO.w  , ao.w  , weight);
            ao.xyz = mix(prevAO.xyz, ao.xyz, weight);
        #endif
    #endif
}
    