/***********************************************/
/*          Copyright (C) 2024 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#if defined STAGE_VERTEX

    void main() {
        gl_Position = vec4(10.0);
    }
    
#elif defined STAGE_FRAGMENT

    /* RENDERTARGETS: 14 */

    void main() {
	    discard; return;
    }

#endif
