/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#if STAGE == STAGE_VERTEX
    #include "/include/utility/transforms.glsl"

    out vec2 texCoords;
    out vec4 color;

    void main() {
        texCoords = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
        color     = gl_Color;

        gl_Position    = ftransform();
        gl_Position.xy = distort(gl_Position.xy);
    }
    
#elif STAGE == STAGE_FRAGMENT
    in vec2 texCoords;
    in vec4 color;

    void main() {
        gl_FragData[0] = texture(colortex0, texCoords) * color;
    }
#endif
