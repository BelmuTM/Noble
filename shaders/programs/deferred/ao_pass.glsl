/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#define RENDER_SCALE 0.5

#include "/include/common.glsl"
#include "/internalSettings.glsl"

/* RENDERTARGETS: 10 */

layout (location = 0) out vec4 ao;

in vec2 textureCoords;
in vec2 vertexCoords;
    
#if AO == 1
    #if AO_TYPE == 1
        #include "/include/fragment/raytracer.glsl"
    #endif
    #include "/include/fragment/ao.glsl"
#endif

void main() {
    vec2 fragCoords = gl_FragCoord.xy * pixelSize / RENDER_SCALE;
	if(saturate(fragCoords) != fragCoords) discard;

    #if AO == 1 && GI == 0
        ao = vec4(0.0, 0.0, 0.0, 1.0);
    #else
        #if GI == 1
            ao = texture(INDIRECT_BUFFER, vertexCoords);
        #endif
        return;
    #endif

    if(isSky(vertexCoords) || isHand(vertexCoords)) return;

    #if AO == 1
        vec3 viewPosition = getViewPosition0(vertexCoords);
        Material material = getMaterial(vertexCoords);

        #if AO_TYPE == 0
            ao.w = SSAO(viewPosition, material.normal);
        #elif AO_TYPE == 1
            ao.w = RTAO(viewPosition, material.normal, ao.xyz);
        #elif AO_TYPE == 2
            ao.w = GTAO(vertexCoords, viewPosition, material.normal, ao.xyz);
        #endif

        ao.w = saturate(ao.w);

        #if AO_FILTER == 1
            vec3 currPosition = vec3(textureCoords, texture(depthtex0, vertexCoords).r);
            vec2 prevCoords   = vertexCoords + getVelocity(currPosition).xy * RENDER_SCALE;
            vec4 prevAO       = texture(INDIRECT_BUFFER, prevCoords);
        
            float weight = 1.0 / max(texture(DEFERRED_BUFFER, prevCoords).w, 1.0);

            ao.w   = mix(prevAO.w  , ao.w  , weight);
            ao.xyz = mix(prevAO.xyz, ao.xyz, weight);
        #endif
    #endif
}
    