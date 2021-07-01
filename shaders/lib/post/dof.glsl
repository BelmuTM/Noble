/***********************************************/
/*       Copyright (C) Noble SSRT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec3 computeDOF(float sceneDepth, vec3 viewPos) {
    float z = sceneDepth * far;
	float coc = min(abs(APERTURE * (FOCAL * (z - centerDepthSmooth)) / (z * (centerDepthSmooth - FOCAL))) * SIZEMULT, (1.0f / viewWidth) * 15.0f);
    float blur = smoothstep(MIN_DISTANCE, DOF_DISTANCE, abs(-viewPos.z - coc));
    vec4 inFocusColor = texture2D(colortex0, texCoords);

    if(sceneDepth == 1.0) return inFocusColor.rgb;

    vec4 outOfFocusColor = fastGaussian(colortex0, vec2(viewWidth, viewHeight), 5.65, 12.5, 20.0);
    return mix(inFocusColor.rgb, outOfFocusColor.rgb, blur);
}