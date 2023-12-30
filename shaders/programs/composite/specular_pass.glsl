/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

/* RENDERTARGETS: 13 */

layout (location = 0) out vec3 lighting;

in vec2 textureCoords;
in vec2 vertexCoords;

#include "/settings.glsl"
#include "/include/taau_scale.glsl"

#include "/include/common.glsl"

#include "/include/atmospherics/constants.glsl"

#include "/include/utility/phase.glsl"

#include "/include/fragment/brdf.glsl"
#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/shadowmapping.glsl"

#include "/include/utility/sampling.glsl"

#if REFRACTIONS == 1
    #include "/include/fragment/refractions.glsl"
#endif

#if REFLECTIONS == 1 && GI == 1 && RENDER_MODE == 0
    vec3 filterSpecularHistory(sampler2D tex, vec2 coords, Material material) {
		vec3 history = vec3(0.0);
        float totalWeight = EPS;

		const int size = 1;

		for(int x = -size; x <= size; x++) {
			for(int y = -size; y <= size; y++) {
				vec2 sampleCoords = coords + vec2(x, y) * texelSize;
				if(saturate(sampleCoords) != sampleCoords) continue;

                float sampleDepth = exp2(texture(MOMENTS_BUFFER, sampleCoords).a);

                uvec4 sampleDataTexture = texture(GBUFFERS_DATA, sampleCoords);
                vec3  sampleNormal      = mat3(gbufferModelView) * decodeUnitVector(vec2(sampleDataTexture.w & 65535u, (sampleDataTexture.w >> 16u) & 65535u) * rcpMaxFloat16);

                float weight  = gaussianDistribution2D(vec2(x, y), 1.0);
                      weight *= pow(exp(-abs(linearizeDepthFast(material.depth0) - linearizeDepthFast(sampleDepth))), 1.0);
                      weight *= pow(max0(dot(material.normal, sampleNormal)), 32.0);

				history     += texture(tex, sampleCoords).rgb * weight;
				totalWeight += weight;
			}
		}
		return history / totalWeight;
    }
#endif

void main() {
    vec2 fragCoords = gl_FragCoord.xy * texelSize / RENDER_SCALE;
	if(saturate(fragCoords) != fragCoords) { discard; return; }

    lighting = texture(DEFERRED_BUFFER, vertexCoords).rgb;

    vec3 coords = vec3(vertexCoords, 0.0);

    vec3 sunSpecular = vec3(0.0), envSpecular = vec3(0.0);

    float depth = texture(depthtex0, vertexCoords).r;

    if(depth != 1.0) {
        Material material = getMaterial(vertexCoords);

        vec3 viewPosition0 = screenToView(vec3(textureCoords, material.depth0));
        vec3 viewPosition1 = screenToView(vec3(textureCoords, material.depth1));

        vec3 directIlluminance = vec3(0.0);
    
        #if defined WORLD_OVERWORLD || defined WORLD_END
            directIlluminance = texelFetch(ILLUMINANCE_BUFFER, ivec2(0), 0).rgb;

            #if defined WORLD_OVERWORLD && defined SUNLIGHT_LEAKING_FIX
                directIlluminance *= float(material.lightmap.y > EPS || isEyeInWater == 1);
            #endif
        #endif

        //////////////////////////////////////////////////////////
        /*-------------------- REFRACTIONS ---------------------*/
        //////////////////////////////////////////////////////////

        #if REFRACTIONS == 1
            if(viewPosition0.z != viewPosition1.z && material.F0 > EPS) {
                lighting = computeRefractions(viewPosition0, material, coords);
            }
        #endif

        //////////////////////////////////////////////////////////
        /*-------------------- REFLECTIONS ---------------------*/
        //////////////////////////////////////////////////////////

        #if SPECULAR == 1
            vec3 visibility = texture(SHADOWMAP_BUFFER, max(coords.xy, texelSize)).rgb;

            #if defined WORLD_OVERWORLD && CLOUDS_SHADOWS == 1 && CLOUDS_LAYER0_ENABLED == 1
                visibility *= getCloudsShadows(viewToScene(viewPosition0));
            #endif

            if(visibility != vec3(0.0)) {
                sunSpecular = computeSpecular(material, -normalize(viewPosition0), shadowVec) * directIlluminance * saturate(visibility);
            }
        #endif

        #if REFLECTIONS == 1
            #if GI == 1 && RENDER_MODE == 0
                envSpecular = filterSpecularHistory(REFLECTIONS_BUFFER, vertexCoords, material);
            #else
                envSpecular = texture(REFLECTIONS_BUFFER, vertexCoords).rgb;
            #endif
        #endif
    }

    vec3 scattering    = vec3(0.0);
    vec3 transmittance = vec3(0.0);

    const int filterSize = 1;

    for(int x = -filterSize; x <= filterSize; x++) {
        for(int y = -filterSize; y <= filterSize; y++) {
            float weight = gaussianDistribution2D(vec2(x, y), 1.0);

            uvec2 packedFog = texture(FOG_BUFFER, coords.xy + vec2(x, y) * texelSize).rg;
            
            scattering    += logLuvDecode(unpackUnormArb(packedFog[0], uvec4(8))) * weight;
            transmittance += logLuvDecode(unpackUnormArb(packedFog[1], uvec4(8))) * weight;
        }
    }
    
    if(isEyeInWater == 1) {
        lighting += sunSpecular;
        lighting  = lighting * transmittance + scattering;
    } else {
        lighting  = lighting * transmittance + scattering;
        lighting += sunSpecular;
    }
    
    lighting += envSpecular;

    vec4 basic    = texture(RASTER_BUFFER, coords.xy);
         lighting = mix(lighting, basic.rgb, basic.a * float(depth >= handDepth));
}
