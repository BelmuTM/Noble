/********************************************************************************/
/*                                                                              */
/*    Noble Shaders                                                             */
/*    Copyright (C) 2025  Belmu                                                 */
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

layout (location = 0) out uvec4 data0;
layout (location = 1) out vec2  data1;

void voxy_emitFragment(VoxyFragmentParameters voxyParameters) {
    uint blockId = max(0u, voxyParameters.customId - 1000u);
    
    vec3 albedo = voxyParameters.sampledColour.rgb * voxyParameters.tinting.rgb;

    #if WHITE_WORLD == 1
        albedo = vec3(1.0);
    #endif

    float roughness = saturate(hardcodedRoughness != 0.0 ? hardcodedRoughness : 1.0);

    float emission = 0.0;

    #if HARDCODED_EMISSION == 1
        if (blockId >= LAVA_ID && blockId < SSS_ID && emission <= EPS) emission = HARDCODED_EMISSION_VAL;
    #endif

    float subsurface = 0.0;

    #if HARDCODED_SSS == 1
        if (blockId > NETHER_PORTAL_ID && blockId <= PLANTS_ID) subsurface = HARDCODED_SSS_VAL;
    #endif

    uint  axis = voxyParameters.face >> 1u;
    float sign = float((voxyParameters.face & 1u) * 2.0 - 1.0);

    vec3 normal = sign * vec3(
        bvec3(axis == 2u, axis == 0u, axis == 1u)
    );

    vec3 labPBRData0 = vec3(1.0, saturate(voxyParameters.lightMap));
    vec4 labPBRData1 = vec4(1.0, emission, 0.0, subsurface);
    vec4 labPBRData2 = vec4(albedo, roughness);

    vec2 encodedNormal = encodeUnitVector(normalize(normal));

    uvec4 shiftedLabPbrData0 = uvec4(round(labPBRData0 * labPBRData0Range), blockId) << uvec4(0, 1, 14, 26);

    data0.x = shiftedLabPbrData0.x | shiftedLabPbrData0.y | shiftedLabPbrData0.z | shiftedLabPbrData0.w;
    data0.y = packUnorm4x8(labPBRData1);
    data0.z = packUnorm4x8(labPBRData2);
    data0.w = packUnorm2x16(encodedNormal);

    data1 = encodedNormal;
}
