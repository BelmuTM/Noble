/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#if defined STAGE_VERTEX

    #include "/include/atmospherics/atmosphere.glsl"

    out vec3 directIlluminance;

    void main() {
        gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
        texCoords   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

        directIlluminance = sampleDirectIlluminance();
    }

#elif defined STAGE_FRAGMENT

    /* RENDERTARGETS: 6 */

    layout (location = 0) out vec3 directIlluminanceOut;

    in vec3 directIlluminance;

    void main() {
        #if defined WORLD_OVERWORLD
            if(ivec2(gl_FragCoord) == ivec2(0)) directIlluminanceOut = directIlluminance;
        #endif
    }
#endif
