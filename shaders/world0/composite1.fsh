/***********************************************/
/*       Copyright (C) Noble SSRT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#version 400 compatibility

varying vec2 texCoords;

#include "/settings.glsl"
#include "/lib/composite_uniforms.glsl"
#include "/lib/frag/dither.glsl"
#include "/lib/frag/noise.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/util/utils.glsl"
///////// REQUIRED FOR PTGI /////////
#include "/lib/util/distort.glsl"
#include "/lib/util/color.glsl"
#include "/lib/util/worldTime.glsl"
#include "/lib/material.glsl"
#include "/lib/lighting/brdf.glsl"
#include "/lib/lighting/shadows.glsl"
/////////////////////////////////////
#include "/lib/lighting/raytracer.glsl"
#include "/lib/lighting/ssgi.glsl"

void main() {
    vec4 Result = texture2D(colortex0, texCoords);

    vec3 GlobalIllumination = vec3(0.0);
    #if SSGI == 1
        float Depth = texture2D(depthtex0, texCoords).r;
        if(Depth == 1.0) {
            gl_FragData[0] = Result;
            return;
        }
        vec3 viewPos = getViewPos();
        vec3 Normal = normalize(texture2D(colortex1, texCoords).rgb * 2.0 - 1.0);

        vec3 lightPos = worldTime >= 12750 ? moonPosition : sunPosition;
        vec3 lightDir = normalize(lightPos);

        float F0 = texture2D(colortex2, texCoords).g;
        bool isMetal = (F0 * 255.0) > 229.5;
        
        if(!isHand(Depth)) GlobalIllumination = isMetal ? vec3(0.0) : 
        computeSSGI(viewToScreen(viewPos), Normal, lightDir, shadowMap(shadowMapResolution));
    #endif

    /* DRAWBUFFERS:06 */
    gl_FragData[0] = Result;
    gl_FragData[1] = vec4(GlobalIllumination, 1.0);
}

