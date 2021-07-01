/***********************************************/
/*       Copyright (C) Noble SSRT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

float edgeDetection() {
    float w = 1.0f / viewWidth;
    float h = 1.0f / viewHeight;

    float depth = texture2D(depthtex0, texCoords).r;
    float depthW0 = texture2D(depthtex0, texCoords + vec2(w, 0.0)).r;
    float depthH0 = texture2D(depthtex0, texCoords + vec2(0.0, -h)).r;
    float depthW1 = texture2D(depthtex0, texCoords + vec2(-w, 0.0)).r;
    float depthH1 = texture2D(depthtex0, texCoords + vec2(0.0, h)).r;

    float ddx = abs((depthW0 - depth) - (depth - depthW1));
    float ddy = abs((depthH0 - depth) - (depth - depthH1));
    return clamp(clamp(ddx + ddy, 0.0, 2.0) / (depth * 0.0005), -1.0, 1.0);
}
