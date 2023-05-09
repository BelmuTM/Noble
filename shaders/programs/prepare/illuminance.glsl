/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#if defined STAGE_VERTEX

    #include "/include/common.glsl"
    #include "/include/atmospherics/atmosphere.glsl"

    out vec3 directIlluminance;
    out vec3[9] skyIlluminance;

    void main() {
        gl_Position   = gl_ModelViewProjectionMatrix * gl_Vertex;
        textureCoords = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

        directIlluminance = evaluateDirectIlluminance();
        skyIlluminance    = evaluateUniformSkyIrradiance();
    }

#elif defined STAGE_FRAGMENT

    /* RENDERTARGETS: 5 */

    layout (location = 0) out vec3 illuminanceOut;

    in vec3 directIlluminance;
    in vec3[9] skyIlluminance;

    void main() {
        #if defined WORLD_OVERWORLD || defined WORLD_END
            if(ivec2(gl_FragCoord) == ivec2(0)) {
                illuminanceOut = directIlluminance; return;
            } else {
                switch(int(gl_FragCoord.x)) {
                    case 1: illuminanceOut = skyIlluminance[0]; return;
                    case 2: illuminanceOut = skyIlluminance[1]; return;
                    case 3: illuminanceOut = skyIlluminance[2]; return;
                    case 4: illuminanceOut = skyIlluminance[3]; return;
                    case 5: illuminanceOut = skyIlluminance[4]; return;
                    case 6: illuminanceOut = skyIlluminance[5]; return;
                    case 7: illuminanceOut = skyIlluminance[6]; return;
                    case 8: illuminanceOut = skyIlluminance[7]; return;
                    case 9: illuminanceOut = skyIlluminance[8]; return;
                    default: discard;
                }
            }
        #endif
    }
#endif
