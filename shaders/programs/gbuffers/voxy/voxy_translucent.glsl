/********************************************************************************/
/*                                                                              */
/*    Noble Shaders                                                             */
/*    Copyright (C) 2026  Belmu                                                 */
/*                                                                              */
/*    This program is free software: you can redistribute it and/or modify      */
/*    it under the terms of the GNU General Public License as published by      */
/*    the Free Software Foundation, either version 3 of the License, or         */
/*    (at your option) any later version.                                       */
/*                                                                              */
/*    This program is distributed in the hope that it will be useful,           */
/*    but WITHOUT ANY WARRANTY; without even the implied warranty of            */
/*    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the             */
/*    GNU General Public License for more details.                              */
/*                                                                              */
/*    You should have received a copy of the GNU General Public License         */
/*    along with this program.  If not, see <https://www.gnu.org/licenses/>.    */
/*                                                                              */
/********************************************************************************/

uniform usampler2D colortex1;
uniform sampler2D colortex3;

uniform sampler2D vxDepthTexOpaque;
uniform sampler2D vxDepthTexTrans;

#define modDepthTex0 vxDepthTexTrans
#define modDepthTex1 vxDepthTexOpaque

#include "/settings.glsl"
#include "/include/taau_scale.glsl"

#include "/include/constants.glsl"

#include "/include/utility/math.glsl"
#include "/include/utility/color.glsl"

#include "/include/utility/transforms.glsl"

#include "/include/utility/material.glsl"

#include "/include/utility/phase.glsl"

#include "/include/atmospherics/constants.glsl"

#if defined WORLD_OVERWORLD || defined WORLD_END
    #include "/include/atmospherics/atmosphere.glsl"
#endif

#include "/include/utility/rng.glsl"

#include "/include/fragment/brdf.glsl"

#include "/include/fragment/gerstner.glsl"

layout (location = 0) out uvec4 data;
layout (location = 1) out vec4 translucents;

void voxy_emitFragment(VoxyFragmentParameters voxyParameters) {
    uint blockId = max(0u, voxyParameters.customId - 1000u);

    vec3 directIlluminance = texelFetch(IRRADIANCE_BUFFER, ivec2(0), 0).rgb;

    vec3 screenPosition = vec3(gl_FragCoord.xy * texelSize, gl_FragCoord.z);
    vec3 viewPosition   = screenToView(screenPosition, vxProjInv, false);
    vec3 scenePosition  = transform(vxModelViewInv, viewPosition);

    Material material;

    translucents = vec4(0.0);

    material.lightmap = saturate(voxyParameters.lightMap);

    uint  axis = voxyParameters.face >> 1u;
    float sign = float((voxyParameters.face & 1) * 2.0 - 1.0);

    material.normal = sign * vec3(
        bvec3(axis == 2u, axis == 0u, axis == 1u)
    );

    material.ao = 1.0;

    // WOTAH
    if (blockId == WATER_ID) {
        material.F0        = waterF0;
        material.roughness = 0.0;
        material.emission  = 0.0;
        material.albedo    = vec3(0.0);

        const mat3 tbn = mat3(
            vec3(1.0, 0.0, 0.0),
            vec3(0.0, 0.0, 1.0),
            vec3(0.0, 1.0, 0.0)
        );

        material.normal = tbn * getWaterNormal(scenePosition + cameraPosition, WATER_OCTAVES);
    } else {
        material.F0 = 0.0;

        material.roughness = saturate(hardcodedRoughness != 0.0 ? hardcodedRoughness : 0.0);

        #if HARDCODED_EMISSION == 1
            if (blockId >= LAVA_ID && blockId < SSS_ID) {
                material.emission = HARDCODED_EMISSION_VAL;
            }
        #endif

        material.albedo = voxyParameters.sampledColour.rgb * voxyParameters.tinting.rgb;

        #if WHITE_WORLD == 1
            material.albedo = vec3(1.0);
        #endif

        #if TONEMAP == ACES
            material.albedo = srgbToAP1Albedo(material.albedo);
        #else
            material.albedo = srgbToLinear(material.albedo);
        #endif

        material.N = vec3(f0ToIOR(material.F0));
        material.K = vec3(0.0);

        vec4 shadowmap      = vec4(1.0, 1.0, 1.0, 0.0);
        vec3 skyIlluminance = vec3(0.0);

        #if defined WORLD_OVERWORLD || defined WORLD_END
            if (material.lightmap.y > EPS) {
                skyIlluminance = evaluateUniformSkyIrradianceApproximation();
            }
        #endif

        translucents.rgb = computeDiffuse(scenePosition, shadowLightVectorWorld, material, false, vec4(1.0, 1.0, 1.0, 0.0), directIlluminance, skyIlluminance, 1.0, 1.0);

        translucents.rgb = max0(log2(translucents.rgb + 1.0));

        translucents.a = voxyParameters.sampledColour.a;
    }

    vec3 labPBRData0 = vec3(1.0, saturate(material.lightmap));
    vec4 labPBRData1 = vec4(1.0, material.emission, material.F0, 0.0);
    vec4 labPBRData2 = vec4(material.albedo, material.roughness);
    
    vec2 encodedNormal = encodeUnitVector(normalize(material.normal));

    uvec4 shiftedLabPbrData0 = uvec4(round(labPBRData0 * labPBRData0Range), blockId) << uvec4(0, 1, 14, 26);

    data.x = shiftedLabPbrData0.x | shiftedLabPbrData0.y | shiftedLabPbrData0.z | shiftedLabPbrData0.w;
    data.y = packUnorm4x8(labPBRData1);
    data.z = packUnorm4x8(labPBRData2);
    data.w = packUnorm2x16(encodedNormal);
}
