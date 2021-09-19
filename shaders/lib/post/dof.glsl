/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

// https://en.wikipedia.org/wiki/Circle_of_confusion#Determining_a_circle_of_confusion_diameter_from_the_object_field

float getCoC(float depth) {
    float cursorDepth = linearizeDepth(centerDepthSmooth);
    float fragDepth = linearizeDepth(depth);

    return fragDepth < 0.56 ? 0.0 : abs((LENS_LENGTH / APERTURE) * ((LENS_LENGTH * (cursorDepth - fragDepth)) / (fragDepth * (cursorDepth - LENS_LENGTH)))) * 0.5;
}

vec3 computeDOF(vec3 color, float depth) {

    vec4 outOfFocusColor = saturate(bokeh(texCoords, colortex0, pixelSize, 6, 30.0));
    return mix(color, outOfFocusColor.rgb, saturate(getCoC(depth)));
}