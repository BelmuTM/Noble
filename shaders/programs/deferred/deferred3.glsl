/***********************************************/
/*          Copyright (C) 2022 Belmu           */
/*       GNU General Public License V3.0       */
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

    /* RENDERTARGETS: 3,6,14 */

    layout (location = 0) out vec4 shadowmap;
    layout (location = 1) out vec4 illuminance;
    layout (location = 2) out float depth;

    in mat3[2] skyIlluminanceMat;
    in vec3 directIlluminance;

    #if defined WORLD_OVERWORLD && SHADOWS == 1
        #include "/include/fragment/shadows.glsl"
    #endif

    #if defined WORLD_OVERWORLD && CLOUDS_SHADOWS == 1 && PRIMARY_CLOUDS == 1
        #include "/include/atmospherics/clouds.glsl"
    #endif

    float computeLowerHiZDepthLevels() {
        float tiles = 0.0;

        for(int i = 1; i < HIZ_LOD_COUNT; i++) {
            int scale   = int(exp2(i)); 
	        vec2 coords = (texCoords - hiZOffsets[i - 1]) * scale;
                 tiles += find2x2MinimumDepth(coords, scale);
        }
        return tiles;
    }

    void main() {
        vec3 viewPos = getViewPos0(texCoords);
        Material mat = getMaterial(texCoords);
        bool sky     = isSky(texCoords);

        vec3 bentNormal = mat.normal;

        depth = computeLowerHiZDepthLevels();

        //////////////////////////////////////////////////////////
        /*-------- AMBIENT OCCLUSION / BENT NORMALS ------------*/
        //////////////////////////////////////////////////////////

        #if GI == 0 && AO == 1
            if(!sky) {
                vec4 ao = texture(colortex10, texCoords);
                if(any(greaterThan(ao.xyz, vec3(0.0)))) bentNormal = clamp01(ao.xyz);
            }
        #endif

        #ifdef WORLD_OVERWORLD
            //////////////////////////////////////////////////////////
            /*----------------- SHADOW MAPPING ---------------------*/
            //////////////////////////////////////////////////////////
            
            #if SHADOWS == 1
                if(!sky) {
                    vec3 geoNormal = texture(colortex3, texCoords).rgb;
                    shadowmap.rgb  = shadowMap(viewToScene(viewPos), geoNormal, shadowmap.a) * mat.parallaxSelfShadowing;
                }
            #endif

            #if CLOUDS_SHADOWS == 1 && PRIMARY_CLOUDS == 1
                illuminance.a = getCloudsShadows(getCloudsShadowPos(gl_FragCoord.xy), shadowLightVector, layer0, 20);
            #endif

            //////////////////////////////////////////////////////////
            /*------------------ SKY ILLUMINANCE -------------------*/
            //////////////////////////////////////////////////////////

            if(ivec2(gl_FragCoord) != ivec2(0))
                illuminance.rgb = mat.lightmap.y > EPS ? getSkyLight(viewToWorld(bentNormal), skyIlluminanceMat) : vec3(0.0);
            else
                illuminance.rgb = directIlluminance;
        #endif
    }
#endif
