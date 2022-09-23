/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#ifdef STAGE_VERTEX

    #include "/include/atmospherics/atmosphere.glsl"

    out vec3 directIlluminance;

    void main() {
        gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
        texCoords   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

        directIlluminance = sampleDirectIlluminance();
    }

#elif defined STAGE_FRAGMENT

    /* RENDERTARGETS: 15 */

    layout (location = 0) out vec3 directIlluminanceOut;

    in vec3 directIlluminance;

    void main() {
        directIlluminanceOut = directIlluminance;
    }
#endif