/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#if STAGE == STAGE_VERTEX
    void main() {
        gl_Position = vec4(-1.0);
        return;
    }
#elif
    void main() {
	    discard;
    }
#endif
