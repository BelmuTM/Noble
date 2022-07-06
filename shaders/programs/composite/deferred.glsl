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

    /* RENDERTARGETS: 3,0,6,12,15 */

    layout (location = 0) out vec3 shadowmap;
    layout (location = 1) out vec3 sky;
    layout (location = 2) out vec4 skyIllum;
    layout (location = 3) out vec4 ao;
    layout (location = 4) out vec4 clouds;

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

        ao.a = 1.0;
        #if AO == 1

            if(clamp(texCoords, vec2(0.0), vec2(AO_RESOLUTION)) == texCoords) {
                vec2 scaledUv = texCoords * (1.0 / AO_RESOLUTION);

                if(!isSky(scaledUv) && !isHand(scaledUv)) {
                    vec3 scaledViewPos = getViewPos0(scaledUv);
                    Material scaledMat = getMaterial(scaledUv);

                    #if AO_TYPE == 0
                        ao.a = SSAO(scaledViewPos, scaledMat.normal);
                    #elif AO_TYPE == 1
                        ao.a = RTAO(scaledViewPos, scaledMat.normal);
                    #else
                        ao.a = GTAO(scaledUv, scaledViewPos, scaledMat.normal);
                    #endif

                    vec3 prevPos = reprojection(vec3(scaledUv, scaledMat.depth0));
                    float prevAO = texture(colortex12, prevPos.xy).a;
                    float weight = clamp01(1.0 - (1.0 / max(texture(colortex5, prevPos.xy).a, 1.0)));

                    if(prevAO >= EPS) ao.a = clamp01(mix(ao.a, prevAO, weight));
                }
            }

        #endif
    }
#endif
