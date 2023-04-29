/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/include/common.glsl"

#if BLOOM == 0
    #include "/programs/discard.glsl"
#else

    /* RENDERTARGETS: 3 */

    layout (location = 0) out vec3 bloom;

    #include "/include/utility/sampling.glsl"
    #include "/include/post/bloom.glsl"

    void main() {
        writeBloom(bloom);
    }
#endif

