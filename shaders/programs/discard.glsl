/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#ifdef STAGE_VERTEX
    void main() {
        gl_Position = vec4(1.0);
    }
#elif defined STAGE_FRAGMENT
    void main() {
	    discard;
    }
#endif
