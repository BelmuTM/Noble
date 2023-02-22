/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#if defined STAGE_VERTEX
    void main() {
        gl_Position = vec4(1.0);
    }
#elif defined STAGE_FRAGMENT
    /* RENDERTARGETS: 2 */

    void main() {
	    discard;
    }
#endif
