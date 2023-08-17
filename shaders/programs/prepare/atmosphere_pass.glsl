/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#if defined WORLD_OVERWORLD || defined WORLD_END
    #include "/settings.glsl"
    #include "/include/taau_scale.glsl"
    
    #include "/include/common.glsl"

    #include "/include/utility/phase.glsl"
    #include "/include/atmospherics/constants.glsl"
    #include "/include/atmospherics/atmosphere.glsl"

    #if defined STAGE_VERTEX

        out vec2 textureCoords;
        out vec3 skyIlluminance;

        void main() {
            gl_Position   = vec4(gl_Vertex.xy * 2.0 - 1.0, 1.0, 1.0);
            textureCoords = gl_Vertex.xy;

            skyIlluminance = evaluateUniformSkyIrradianceApproximation();
        }

    #elif defined STAGE_FRAGMENT

        /* RENDERTARGETS: 6 */

        layout (location = 0) out vec3 sky;

        in vec2 textureCoords;
        in vec3 skyIlluminance;

        void main() {
            vec3 skyRay = normalize(unprojectSphere(textureCoords));
                 sky    = evaluateAtmosphericScattering(skyRay, skyIlluminance);
        }
    #endif
#else
    #include "/programs/discard.glsl"
#endif
