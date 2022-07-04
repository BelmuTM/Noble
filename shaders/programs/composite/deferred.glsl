/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#if defined STAGE_VERTEX

    out vec3 skyIlluminance;
    #include "/include/atmospherics/atmosphere.glsl"

    void main() {
        gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
        texCoords   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

        skyIlluminance = sampleSkyIlluminance();
    }

#elif defined STAGE_FRAGMENT

    /* RENDERTARGETS: 3,0,6,15 */

    layout (location = 0) out vec4 shadowmap;
    layout (location = 1) out vec3 sky;
    layout (location = 2) out vec4 skyIllum;
    layout (location = 3) out vec4 clouds;

    #include "/include/atmospherics/atmosphere.glsl"
    #include "/include/atmospherics/clouds.glsl"
    
    #include "/include/fragment/raytracer.glsl"
    #include "/include/fragment/ao.glsl"
    #include "/include/fragment/shadows.glsl"
    #include "/include/post/taa.glsl"

    in vec3 skyIlluminance;

    void main() {
        vec3 viewPos = getViewPos0(texCoords);
        Material mat = getMaterial(texCoords);

        #ifdef WORLD_OVERWORLD
            /*    ------- SHADOW MAPPING -------    */
            float ssDepth = 0.0;
            shadowmap.rgb = shadowMap(viewPos, texture(colortex2, texCoords).rgb, ssDepth);
            skyIllum.a    = ssDepth;

            /*    ------- ATMOSPHERIC SCATTERING -------    */
            vec3 skyRay       = normalize(unprojectSphere(texCoords * (1.0 / ATMOSPHERE_RESOLUTION)));
                 sky          = atmosphericScattering(skyRay, skyIlluminance);
                 skyIllum.rgb = skyIlluminance;

            /*    ------- VOLUMETRIC CLOUDS -------    */
            #if CLOUDS == 1
                vec2 cloudsCoords = texCoords * (1.0 / CLOUDS_RESOLUTION);
                
                clouds = vec4(0.0, 0.0, 0.0, 1.0);

                if(clamp01(cloudsCoords) == cloudsCoords) {
                    float depth;
                    vec3 cloudsRay = normalize(unprojectSphere(cloudsCoords));
                         clouds    = cloudsScattering(cloudsRay, depth);

                    /* Aerial Perspective */
                    const float cloudsMiddle = CLOUDS_ALTITUDE + (CLOUDS_THICKNESS * 0.5);
                    vec2 dists               = intersectSphere(atmosRayPos, cloudsRay, earthRad + cloudsMiddle);

                    if(dists.y >= 0.0) { 
                        float distToCloud = cameraPosition.y >= cloudsMiddle ? dists.x : dists.y;
                        clouds            = mix(vec4(0.0, 0.0, 0.0, 1.0), clouds, exp(-5e-5 * distToCloud));
                    }

                    vec3 prevPos    = reprojection(viewToScreen(normalize(viewPos) * depth));
                    vec4 prevClouds = texture(colortex15, prevPos.xy);

                    if(!all(equal(prevClouds, vec4(0.0)))) clouds = mix(clouds, prevClouds, 0.96);
                }
            #endif
        #endif

        shadowmap.a = 1.0;
        #if AO == 1
            if(!isSky(texCoords) && !isHand(texCoords)) {
                #if AO_TYPE == 0
                    shadowmap.a = SSAO(viewPos, mat.normal);
                #elif AO_TYPE == 1
                    shadowmap.a = RTAO(viewPos, mat.normal);
                #else
                    shadowmap.a = GTAO(texCoords, viewPos, mat.normal);
                #endif
                shadowmap.a = clamp01(shadowmap.a);
            }
        #endif
    }
#endif
