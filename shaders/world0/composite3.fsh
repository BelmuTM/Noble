/***********************************************/
/*       Copyright (C) Noble RT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#version 400 compatibility

varying vec2 texCoords;

#include "/settings.glsl"
#include "/lib/composite_uniforms.glsl"
#include "/lib/frag/dither.glsl"
#include "/lib/frag/noise.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/util/utils.glsl"
#include "/lib/util/color.glsl"
#include "/lib/util/worldTime.glsl"
#include "/lib/util/blur.glsl"
#include "/lib/material.glsl"
#include "/lib/lighting/brdf.glsl"
#include "/lib/util/distort.glsl"
#include "/lib/atmospherics/volumetric.glsl"

const bool colortex6Clear = false;
const float rainMinAmbientBrightness = 0.2;

/*------------------ LIGHTMAP ------------------*/
vec3 getLightmapColor(vec2 lightMap) {
    lightMap.x = TORCHLIGHT_MULTIPLIER * pow(lightMap.x, 5.06);

    vec3 TorchLight = lightMap.x * TORCH_COLOR;
    vec3 SkyLight = (lightMap.y * lightMap.y) * skyColor;
    return vec3(TorchLight + clamp(SkyLight - rainStrength, EPS, 1.0));
}

void main() {
    vec3 viewPos = getViewPos();
    vec3 viewDir = normalize(-viewPos);
    vec3 lightDir = normalize(shadowLightPosition);

    vec4 tex0 = texture2D(colortex0, texCoords);
    vec4 tex1 = texture2D(colortex1, texCoords);
    vec4 tex2 = texture2D(colortex2, texCoords);
    tex0.rgb = toLinear(tex0.rgb);

    material data = getMaterial(tex0, tex1, tex2);
    vec3 normal = normalize(data.normal.xyz);
    float depth = texture2D(depthtex0, texCoords).r;

    data.albedo = mix(texture2D(colortex4, texCoords).rgb, data.albedo, data.alpha);
    
    float VolumetricLighting = 0.0;
    #if VL == 1
        VolumetricLighting = clamp((computeVL(viewPos) * VL_BRIGHTNESS) - rainStrength, 0.0, 1.0);
    #endif

    if(depth == 1.0) {
        /*DRAWBUFFERS:04*/
        gl_FragData[0] = tex0;
        gl_FragData[1] = vec4(VolumetricLighting);
        return;
    }

    vec3 Shadow = texture2D(colortex7, texCoords).rgb;
    vec3 lightmapColor = vec3(0.0);
    float AmbientOcclusion = 1.0;
    
    #if GI == 0
        vec2 lightMap = data.lightmap;
        lightmapColor = getLightmapColor(lightMap);

        #if SSAO == 1
            AmbientOcclusion = bilateralBlur(colortex5).a;
        #endif
    #endif

    vec4 GlobalIllumination = texture2D(colortex6, texCoords);
    #if GI == 1
        #if GI_FILTER == 1
            GlobalIllumination = edgeAwareBlur(viewPos, normal, colortex6, 
            viewSize * GI_FILTER_RES, GI_FILTER_SIZE, GI_FILTER_QUALITY, 13.0);
        #endif
    #endif

    vec3 Lighting = Cook_Torrance(normal, viewDir, lightDir, data, lightmapColor, Shadow, GlobalIllumination.rgb);
    bool isEmissive = data.emission != 0.0;

    if(getBlockId(texCoords) == 1) {
        float depthDist = distance(
		    linearizeDepth(texture2D(depthtex0, texCoords).r),
		    linearizeDepth(texture2D(depthtex1, texCoords).r)
	    );

        // Absorption
        depthDist = max(0.0, depthDist);
        float density = depthDist * 6.5e-1;

	    vec3 absorption = exp2(-(density / log(2.0)) * WATER_ABSORPTION_COEFFICIENTS);
        Lighting *= absorption;

        // Foam
        #if WATER_FOAM == 1
            vec4 falloffColor = vec4(absorption, FOAM_BRIGHTNESS);

            if(depthDist < FOAM_FALLOFF_DISTANCE * FOAM_EDGE_FALLOFF && isEyeInWater == 0) {
                float falloff = (depthDist / FOAM_FALLOFF_DISTANCE) + FOAM_FALLOFF_BIAS;
                vec3 edge = falloffColor.rgb * falloff * falloffColor.a * Shadow;

                float leading = depthDist / (FOAM_FALLOFF_DISTANCE * FOAM_EDGE_FALLOFF);
	            Lighting = mix(Lighting + edge, Lighting, leading);
            }
        #endif
    }

    /*DRAWBUFFERS:047*/
    gl_FragData[0] = vec4(Lighting * AmbientOcclusion, 1.0);
    gl_FragData[1] = vec4(data.albedo, VolumetricLighting);
    gl_FragData[2] = vec4(luma(Lighting) > 0.3 ? Lighting : vec3(0.0), 1.0);
}
