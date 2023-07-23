/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/include/taau_scale.glsl"
#include "/include/common.glsl"

#if GI == 1
    /* RENDERTARGETS: 4,9,10 */

    layout (location = 0) out vec4 color;
    layout (location = 1) out uvec2 firstBounceData;
    layout (location = 2) out vec4 temporalData;
#else
    /* RENDERTARGETS: 4,10 */

    layout (location = 0) out vec4 color;
    layout (location = 1) out vec4 temporalData;
#endif

in vec2 textureCoords;
in vec2 vertexCoords;

#include "/include/atmospherics/constants.glsl"

#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/brdf.glsl"

#include "/include/atmospherics/celestial.glsl"

#if GI == 1
    #include "/include/fragment/pathtracer.glsl"
#endif

void main() {
    vec2 fragCoords = gl_FragCoord.xy * pixelSize / RENDER_SCALE;
	if(saturate(fragCoords) != fragCoords) { discard; return; }

    #if GI == 1
        vec2 tmpTextureCoords = textureCoords / GI_SCALE;
        vec2 tmpVertexCoords  = vertexCoords / GI_SCALE;
    #else
        vec2 tmpTextureCoords = textureCoords;
        vec2 tmpVertexCoords  = vertexCoords;
    #endif

    float depth         = texture(depthtex0, tmpVertexCoords).r;
    vec3  viewPosition0 = screenToView(vec3(tmpTextureCoords, depth));

    if(depth == 1.0) {
        vec3 sky = renderAtmosphere(tmpVertexCoords, viewPosition0);
        #if GI == 1
            firstBounceData.x = packUnormArb(logLuvEncode(sky), uvec4(8));
        #else
            color.rgb = sky;
        #endif
        return;
    }

    Material material = getMaterial(tmpVertexCoords);

    #if HARDCODED_SSS == 1
        if(material.blockId > NETHER_PORTAL_ID && material.blockId <= PLANTS_ID && material.subsurface <= EPS) material.subsurface = HARDCODED_SSS_VAL;
    #endif

    #if AO_FILTER == 1 && GI == 0 || GI == 1
        vec3  currPosition = vec3(textureCoords, depth);
        vec2  prevCoords   = vertexCoords + getVelocity(currPosition).xy * RENDER_SCALE;
        vec4  history      = texture(DEFERRED_BUFFER, prevCoords);

        #if RENDER_MODE == 0
            float prevDepth = exp2(texture(MOMENTS_BUFFER, prevCoords).a);
            float weight    = pow(exp(-abs(linearizeDepthFast(depth) - linearizeDepthFast(prevDepth))), TEMPORAL_DEPTH_WEIGHT_SIGMA);

            vec2 pixelCenterDist = 1.0 - abs(2.0 * fract(prevCoords * viewSize) - 1.0);
                 weight         *= sqrt(pixelCenterDist.x * pixelCenterDist.y) * 0.2 + 0.8;

            temporalData.a = log2(depth);
        #else
            float weight = float(hideGUI);
        #endif

        color.a = (history.a * weight * float(clamp(prevCoords, 0.0, RENDER_SCALE) == prevCoords) * float(!isHand(vertexCoords))) + 1.0;
    #endif

    #if GI == 0
        color.rgb = vec3(0.0);

        if(material.F0 * maxVal8 <= 229.5) {
            vec3 skyIlluminance = vec3(0.0), directIlluminance = vec3(0.0);
            float cloudsShadows = 1.0; vec4 shadowmap = vec4(1.0, 1.0, 1.0, 0.0);

            #if defined WORLD_OVERWORLD || defined WORLD_END
                directIlluminance = texelFetch(ILLUMINANCE_BUFFER, ivec2(0), 0).rgb;

                #if defined WORLD_OVERWORLD && CLOUDS_SHADOWS == 1 && CLOUDS_LAYER0_ENABLED == 1
                    cloudsShadows = getCloudsShadows(viewToScene(viewPosition0));
                #endif

                skyIlluminance = texture(ILLUMINANCE_BUFFER, vertexCoords).rgb;

                #if SHADOWS == 1
                    shadowmap = texture(SHADOWMAP_BUFFER, vertexCoords);
                #endif
            #endif

            float ao = 1.0;
            #if AO == 1
                ao = texture(AO_BUFFER, vertexCoords).a;
            #endif

            color.rgb = computeDiffuse(viewPosition0, shadowVec, material, shadowmap, directIlluminance, skyIlluminance, ao, cloudsShadows);
        }
    #else
        vec3 direct   = vec3(0.0);
        vec3 indirect = vec3(1.0);

        if(clamp(vertexCoords, vec2(0.0), vec2(GI_SCALE)) == vertexCoords) {

            pathtrace(color.rgb, vec3(vertexCoords, depth), direct, indirect);

            #if GI_TEMPORAL_ACCUMULATION == 1
                float frameWeight = 1.0 / max(color.a * float(linearizeDepthFast(material.depth0) >= MC_HAND_DEPTH), 1.0);

                color.rgb = mix(history.rgb, color.rgb, frameWeight);

                uvec2 packedFirstBounceData = texture(GI_DATA_BUFFER, prevCoords).rg;

                direct   = max0(mix(logLuvDecode(unpackUnormArb(packedFirstBounceData[0], uvec4(8))), direct  , frameWeight));
                indirect = max0(mix(logLuvDecode(unpackUnormArb(packedFirstBounceData[1], uvec4(8))), indirect, frameWeight));

                #if GI_FILTER == 1
                    float luminance = luminance(color.rgb);
                    temporalData.rg = vec2(luminance, luminance * luminance);

                    vec2 prevMoments     = texture(MOMENTS_BUFFER, prevCoords).rg;
                         temporalData.rg = mix(prevMoments, temporalData.rg, frameWeight);
                         temporalData.b  = sqrt(abs(temporalData.g - temporalData.r * temporalData.r));
                #endif
            #endif
        }

        firstBounceData.x = packUnormArb(logLuvEncode(direct  ), uvec4(8));
        firstBounceData.y = packUnormArb(logLuvEncode(indirect), uvec4(8));
    #endif
}
