/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/include/common.glsl"

#if GI == 0 && REFLECTIONS == 1

    /* RENDERTARGETS: 2 */
    
    layout (location = 0) out vec3 reflections;

    #include "/include/fragment/brdf.glsl"
    
    #include "/include/atmospherics/celestial.glsl"

    #include "/include/fragment/raytracer.glsl"
    #include "/include/fragment/reflections.glsl"
#endif

void main() {
    #if GI == 0 && REFLECTIONS == 1
        if(isSky(texCoords)) discard;

        vec3 viewPosition = getViewPosition0(texCoords);
        Material material = getMaterial(texCoords);
                    
        #if REFLECTIONS_TYPE == 0
            reflections = simpleReflections(viewPosition, material);
        #else
            reflections = roughReflections(viewPosition, material);
        #endif
    #else
        discard;
    #endif
}
