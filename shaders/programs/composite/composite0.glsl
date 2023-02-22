/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

/* RENDERTARGETS: 2 */

#if GI == 0 && REFLECTIONS == 1
    layout (location = 0) out vec3 reflections;

    #include "/include/fragment/brdf.glsl"
    
    #include "/include/atmospherics/celestial.glsl"

    #include "/include/fragment/raytracer.glsl"
    #include "/include/fragment/reflections.glsl"
#endif

void main() {
    #if GI == 0 && REFLECTIONS == 1
        if(isSky(texCoords)) discard;

        vec3 viewPos = getViewPos0(texCoords);
        Material mat = getMaterial(texCoords);
                    
        #if REFLECTIONS_TYPE == 0
            reflections = simpleReflections(viewPos, mat);
        #else
            reflections = roughReflections(viewPos, mat);
        #endif
    #else
        discard;
    #endif
}
