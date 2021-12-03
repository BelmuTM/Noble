/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/include/utility/blur.glsl"
#include "/include/post/bloom.glsl"
#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/shadows.glsl"
#include "/include/atmospherics/fog.glsl"

// https://en.wikipedia.org/wiki/Circle_of_confusion#Determining_a_circle_of_confusion_diameter_from_the_object_field
float getCoC(float fragDepth, float cursorDepth) {
    return fragDepth < 0.56 ? 0.0 : abs((FOCAL / APERTURE) * ((FOCAL * (cursorDepth - fragDepth)) / (fragDepth * (cursorDepth - FOCAL)))) * 0.5;
}

vec3 depthOfField(vec3 color, float coc) {
    vec4 outOfFocusColor = bokeh(texCoords, colortex0, pixelSize, 6, DOF_RADIUS);
    return clamp01(mix(color, outOfFocusColor.rgb, quintic(0.0, 1.0, coc)));
}

void main() {
    vec3 viewPos = getViewPos(texCoords);
    vec4 color = texture(colortex0, texCoords);

    vec4 bloom = BLOOM == 1 ? writeBloom() : vec4(0.0);

    float coc = 1.0;
    #if DOF == 1
        coc = getCoC(linearizeDepth(texture(depthtex0, texCoords).r), linearizeDepth(centerDepthSmooth));
        color.rgb = depthOfField(color.rgb, coc);
    #endif
     
    color.rgb += fog(viewPos, vec3(0.0), vec3(1.0), (rainStrength * float(RAIN_FOG == 1)) + isEyeInWater, 0.03); // Applying Fog

    /*DRAWBUFFERS:05*/
    gl_FragData[0] = color;
    gl_FragData[1] = vec4(bloom.rgb, coc);
}
