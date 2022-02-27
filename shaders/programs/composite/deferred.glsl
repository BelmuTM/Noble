/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/bufferSettings.glsl"

#if defined STAGE_VERTEX

    out vec3 skyIlluminance;
    #include "/include/atmospherics/atmosphere.glsl"

    void main() {
        gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
        texCoords   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

        skyIlluminance = sampleSkyIlluminance();
    }

#elif defined STAGE_FRAGMENT

    /* RENDERTARGETS: 3,6,7 */

    layout (location = 0) out vec4 shadowmap;
    layout (location = 1) out vec3 sky;
    layout (location = 2) out vec3 skyIllum;

    #include "/include/atmospherics/atmosphere.glsl"
    #include "/include/atmospherics/clouds.glsl"
    
    #include "/include/fragment/raytracer.glsl"
    #include "/include/fragment/ao.glsl"
    #include "/include/fragment/shadows.glsl"

    in vec3 skyIlluminance;

    void main() {
        vec3 viewPos = getViewPos0(texCoords);
        Material mat = getMaterial(texCoords);

        #ifdef WORLD_OVERWORLD
            /*    ------- SHADOW MAPPING -------    */
            shadowmap.rgb = shadowMap(transMAD(gbufferModelViewInverse, viewPos), transMAD(gbufferModelViewInverse, mat.normal));

            /*    ------- ATMOSPHERIC SCATTERING -------    */
            if(clamp(texCoords, vec2(0.0), vec2(ATMOSPHERE_RESOLUTION + 1e-2)) == texCoords) {
                vec3 rayDir = unprojectSphere(texCoords * (1.0 / ATMOSPHERE_RESOLUTION));
                sky         = atmosphericScattering(normalize(rayDir), skyIlluminance);
            }
            skyIllum = skyIlluminance;

            //sky += cloudsScattering(unprojectSphere(texCoords * (1.0 / ATMOSPHERE_RESOLUTION)));
        #endif

        shadowmap.a = 1.0;
        
        #if AO == 1
            if(!isSky(texCoords)) {
                #if AO_TYPE == 0
                    shadowmap.a = computeSSAO(viewPos, mat.normal);
                #else
                    shadowmap.a = computeRTAO(viewPos, mat.normal);
                #endif
            }
        #endif
    }
#endif
