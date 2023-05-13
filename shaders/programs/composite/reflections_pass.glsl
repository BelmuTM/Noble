/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/include/common.glsl"

#if REFLECTIONS == 0 || GI == 1
    #include "/programs/discard.glsl"
#else
    #if defined STAGE_VERTEX
        #include "/programs/vertex_simple.glsl"

    #elif defined STAGE_FRAGMENT

        /* RENDERTARGETS: 2 */
    
        layout (location = 0) out vec3 reflections;

        in vec2 textureCoords;

        #include "/include/fragment/brdf.glsl"
    
        #include "/include/atmospherics/celestial.glsl"

        #include "/include/fragment/raytracer.glsl"
        #include "/include/fragment/reflections.glsl"

        void main() {
            if(isSky(textureCoords)) discard;

            vec3 viewPosition = getViewPosition0(textureCoords);
            Material material = getMaterial(textureCoords);
                    
            #if REFLECTIONS_TYPE == 0
                reflections = computeSmoothReflections(viewPosition, material);
            #else
                reflections = computeRoughReflections(viewPosition, material);
            #endif

            if(isHand(textureCoords)) return;

            vec3 currPosition = vec3(textureCoords, material.depth0);
            vec3 prevPosition = currPosition - getVelocity(currPosition);
            vec3 prevColor    = texture(REFLECTIONS_BUFFER, prevPosition.xy).rgb;

            if(any(isnan(prevColor))) prevColor = reflections;

            float weight = 1.0 / max(texture(DEFERRED_BUFFER, prevPosition.xy).w, 1.0);
            reflections  = max0(mix(prevColor, reflections, weight));
        }
    #endif
#endif
