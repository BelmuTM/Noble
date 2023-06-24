/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/include/common.glsl"
#include "/internalSettings.glsl"

/* RENDERTARGETS: 10 */

layout (location = 0) out vec4 ao;

in vec2 textureCoords;
    
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
            ao = texture(INDIRECT_BUFFER, textureCoords);
        #endif
        return;
    #endif

    if(isSky(textureCoords) || isHand(textureCoords)) return;

    #if AO == 1
        vec3 viewPosition = getViewPosition0(textureCoords);
        Material material = getMaterial(textureCoords);

        #if AO_TYPE == 0
            ao.w = SSAO(viewPosition, material.normal);
        #elif AO_TYPE == 1
            ao.w = RTAO(viewPosition, material.normal, ao.xyz);
        #elif AO_TYPE == 2
            ao.w = GTAO(textureCoords, viewPosition, material.normal, ao.xyz);
        #endif

        ao.w = saturate(ao.w);

        #if AO_FILTER == 1
            vec3 currPosition = vec3(textureCoords, material.depth0);
            vec3 prevPosition = currPosition - getVelocity(currPosition);
            vec4 prevAO       = texture(INDIRECT_BUFFER, prevPosition.xy);
        
            float weight = 1.0 / max(texture(DEFERRED_BUFFER, prevPosition.xy).w, 1.0);

            ao.w   = mix(prevAO.w  , ao.w  , weight);
            ao.xyz = mix(prevAO.xyz, ao.xyz, weight);
        #endif
    #endif
}
    