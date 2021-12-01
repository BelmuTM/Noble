/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/fragmentSettings.glsl"

#if STAGE == STAGE_VERTEX

    out vec3 skyIlluminance;
    #include "/include/utility/math.glsl"

    void main() {
        gl_Position = ftransform();
        texCoords = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

        int samples = 8;
        skyIlluminance = vec3(0.0);

        #if WORLD == OVERWORLD
            for(int x = 0; x < samples; x++) {
                for(int y = 0; y < samples; y++) {
                    vec3 dir = generateUnitVector((1.0 / samples) * vec2(x, y));
                    skyIlluminance += texture(colortex7, projectSphere(dir) * ATMOSPHERE_RESOLUTION).rgb;
                }
            }
            skyIlluminance *= 1.0 / (samples * samples);
        #endif
    }

#elif STAGE == STAGE_FRAGMENT

    #include "/include/atmospherics/atmosphere.glsl"
    #include "/include/fragment/raytracer.glsl"
    #include "/include/fragment/shadows.glsl"

    in vec3 skyIlluminance;

    void main() {
        vec3 shadowmap = vec3(0.0);
        vec3 sky       = vec3(0.0);

        #if WORLD == OVERWORLD
            /*    ------- SHADOW MAPPING -------    */
            #if SHADOWS == 1
                shadowmap = shadowMap(getViewPos(texCoords));
            #endif

            /*    ------- ATMOSPHERIC SCATTERING -------    */
            if(clamp(texCoords, vec2(0.0), vec2(ATMOSPHERE_RESOLUTION + 1e-2)) == texCoords) {
                vec3 rayDir = unprojectSphere(texCoords * (1.0 / ATMOSPHERE_RESOLUTION));
                sky = atmosphericScattering(atmosRayPos, rayDir, skyIlluminance);
            }
        #endif

        /*DRAWBUFFERS:4789*/
        gl_FragData[0] = sRGBToLinear(texture(colortex0, texCoords));
        gl_FragData[1] = vec4(sky,            1.0);
        gl_FragData[2] = vec4(skyIlluminance, 1.0);
        gl_FragData[3] = vec4(shadowmap,      1.0);
    }
#endif
