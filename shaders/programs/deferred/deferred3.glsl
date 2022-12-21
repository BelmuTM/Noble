/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/include/atmospherics/atmosphere.glsl"

#if defined STAGE_VERTEX

    out mat3[2] skyIlluminanceMat;
    out vec3 directIlluminance;

    void main() {
        gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
        texCoords   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

        skyIlluminanceMat = sampleSkyIlluminanceComplex();
        directIlluminance = texelFetch(colortex6, ivec2(0), 0).rgb;
    }

#elif defined STAGE_FRAGMENT

    /* RENDERTARGETS: 3,4,6 */

    layout (location = 0) out vec4 shadowmap;
    layout (location = 1) out vec4 cloudsShadows;
    layout (location = 2) out vec3 skyIlluminance;

    in mat3[2] skyIlluminanceMat;
    in vec3 directIlluminance;

    #if defined WORLD_OVERWORLD && SHADOWS == 1
        #include "/include/fragment/shadows.glsl"
    #endif

    #if defined WORLD_OVERWORLD && CLOUDS_SHADOWS == 1 && PRIMARY_CLOUDS == 1
        #include "/include/atmospherics/clouds.glsl"
    #endif

    void main() {
        vec3 viewPos = getViewPos0(texCoords);
        Material mat = getMaterial(texCoords);
        bool sky     = isSky(texCoords);

        vec3 bentNormal = mat.normal;

        //////////////////////////////////////////////////////////
        /*-------- AMBIENT OCCLUSION / BENT NORMALS ------------*/
        //////////////////////////////////////////////////////////

        #if GI == 0 && AO == 1
            if(!sky) {
                vec4 aoHistory = texture(colortex10, texCoords);
                if(any(greaterThan(aoHistory.rgb, vec3(0.0)))) bentNormal = clamp01(aoHistory.rgb);
            }
        #endif

        #ifdef WORLD_OVERWORLD
            //////////////////////////////////////////////////////////
            /*----------------- SHADOW MAPPING ---------------------*/
            //////////////////////////////////////////////////////////
            
            #if SHADOWS == 1
                if(!sky) {
                    vec4 tmp = texture(colortex3, texCoords);
                    shadowmap.rgb = shadowMap(viewToScene(viewPos), tmp.rgb, shadowmap.a) * tmp.a;
                }
            #endif

            #if CLOUDS_SHADOWS == 1 && PRIMARY_CLOUDS == 1
                cloudsShadows.a = getCloudsShadows(getCloudsShadowPos(gl_FragCoord.xy), shadowLightVector, layer0, 20);
            #endif

            //////////////////////////////////////////////////////////
            /*------------------ SKY ILLUMINANCE -------------------*/
            //////////////////////////////////////////////////////////

            if(ivec2(gl_FragCoord) != ivec2(0))
                skyIlluminance = mat.lightmap.y > EPS ? getSkyLight(viewToWorld(bentNormal), skyIlluminanceMat) : vec3(0.0);
            else
                skyIlluminance = directIlluminance;
        #endif
    }
#endif
