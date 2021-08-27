/***********************************************/
/*       Copyright (C) Noble RT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

// Thanks WoMspace#7331 for helping with the CoC!
float getCoC(float depth) {
    float cursorDepth = linearizeDepth(centerDepthSmooth);
    float fragDepth = linearizeDepth(depth);
    
    return abs((LENS_LENGTH / APERTURE) * ((LENS_LENGTH * (cursorDepth - fragDepth)) / (fragDepth * (cursorDepth - LENS_LENGTH)))) * 0.5;
}

vec3 computeDOF(vec3 color, float depth) {

    vec4 outOfFocusColor = bokeh(texCoords, colortex0, pixelSize, 6, 30.0);
    return mix(color, outOfFocusColor.rgb, getCoC(depth));
}