/***********************************************/
/*          Copyright (C) 2024 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#if defined WORLD_OVERWORLD || defined WORLD_END
    #if defined STAGE_VERTEX
        #include "/settings.glsl"
        #include "/include/taau_scale.glsl"
        
        #include "/include/common.glsl"

        #include "/include/utility/phase.glsl"
        #include "/include/atmospherics/constants.glsl"
        #include "/include/atmospherics/atmosphere.glsl"

        out vec3 directIlluminance;
        out vec3[9] skyIlluminance;

        void main() {
            gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 1.0, 1.0);

            directIlluminance = evaluateDirectIlluminance();
            skyIlluminance    = evaluateUniformSkyIrradiance();
        }

    #elif defined STAGE_FRAGMENT

        /* RENDERTARGETS: 5 */

        layout (location = 0) out vec3 illuminanceOut;

        in vec3 directIlluminance;
        in vec3[9] skyIlluminance;

        #include "/settings.glsl"
        #include "/include/taau_scale.glsl"
        
        #include "/include/common.glsl"

        #include "/include/utility/phase.glsl"
        #include "/include/atmospherics/constants.glsl"
        #include "/include/atmospherics/atmosphere.glsl"

        void main() {
            illuminanceOut = vec3(0.0);

            if(int(gl_FragCoord.y) == 0) {
                if(int(gl_FragCoord.x) == 0) {
                    illuminanceOut = directIlluminance;
                } else if(int(gl_FragCoord.x) > 0 && int(gl_FragCoord.x) < 10) {
                    illuminanceOut = skyIlluminance[int(gl_FragCoord.x) - 1];
                }
            }
        }
        
    #endif
#else
    #include "/programs/discard.glsl"
#endif
