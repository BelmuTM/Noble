/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#if defined WORLD_OVERWORLD
    #include "/include/atmospherics/atmosphere.glsl"
#endif

#if defined STAGE_VERTEX

    out vec3 skyIlluminance;

    void main() {
        gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
        texCoords   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

        #if defined WORLD_OVERWORLD
            skyIlluminance = sampleSkyIlluminanceSimple();
        #endif
    }

#elif defined STAGE_FRAGMENT

    /* RENDERTARGETS: 12 */

    layout (location = 0) out vec4 sky;

    in vec3 skyIlluminance;

    void main() {
        #if defined WORLD_OVERWORLD
            vec3 skyRay  = normalize(unprojectSphere(texCoords));
                 sky.rgb = atmosphericScattering(skyRay, skyIlluminance);
        #endif
    }
#endif
