/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

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
            ao = texture(colortex10, texCoords);
        #endif
        return;
    #endif

    if(isSky(texCoords) || isHand(texCoords)) return;

    //////////////////////////////////////////////////////////
    /*-------- AMBIENT OCCLUSION / BENT NORMALS ------------*/
    //////////////////////////////////////////////////////////

    #if AO == 1
        vec3 viewPos = getViewPos0(texCoords);
        Material mat = getMaterial(texCoords);

        #if AO_TYPE == 0
            ao.a = SSAO(viewPos, mat.normal);
        #elif AO_TYPE == 1
            ao.a = RTAO(viewPos, mat.normal, ao.rgb);
        #elif AO_TYPE == 2
            ao.a = GTAO(texCoords, viewPos, mat.normal, ao.rgb);
        #endif

        ao.a   = clamp01(ao.a);
        ao.rgb = max0(ao.rgb);

        #if AO_FILTER == 1
            vec3 currPos = vec3(texCoords, mat.depth0);
            vec3 prevPos = currPos - getVelocity(currPos);
            vec4 prevAO  = texture(colortex10, prevPos.xy);
            float weight = clamp01(1.0 - (1.0 / max(texture(colortex13, prevPos.xy).a, 1.0)));

            ao.a   = mix(ao.a, prevAO.a, weight);
            ao.rgb = mix(ao.rgb, prevAO.rgb, weight);
        #endif
    #endif
}
    