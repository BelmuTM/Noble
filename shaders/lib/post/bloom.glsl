/***********************************************/
/*       Copyright (C) Noble SSRT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec4 Bloom(int widthMultiplier, int heightMultiplier) {
    vec4 bloom = vec4(0.0);

    int SAMPLES;
    for(int i = -widthMultiplier ; i <= widthMultiplier; i++) {
        for(int j = -heightMultiplier; j <= heightMultiplier; j++) {
            vec2 offset = vec2((j * 1.0 / viewWidth), (i * 1.0 / viewHeight));
            
            bloom += texture2D(colortex0, texCoords + offset);
            SAMPLES++;
        }
    }
    bloom /= SAMPLES;

    return bloom;
}
