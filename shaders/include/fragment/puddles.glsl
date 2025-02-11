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

float calculatePuddleRipples(vec2 position) {
    const mat4x2 rippleOffsets = mat4x2(vec2(0.08, 0.13), vec2(0.1, -0.2), vec2(-0.25, 0.12), vec2(-0.13, -0.23));

    float time = frameTimeCounter * 1.1;

    position *= 1.5;

    float ripple  = texture(noisetex, position + time * rippleOffsets[0]).b;
          ripple += texture(noisetex, position + time * rippleOffsets[1]).b;
          ripple += texture(noisetex, position + time * rippleOffsets[2]).b;
          ripple += texture(noisetex, position + time * rippleOffsets[3]).b;

    return ripple;
}

vec3 getPuddleNormals(vec2 position, float strength) {
    const float dStep = 1e-3;

    vec2 steps;
    steps.x = calculatePuddleRipples(position + vec2( dStep, -dStep));
	steps.y = calculatePuddleRipples(position + vec2(-dStep,  dStep));
	steps  -= calculatePuddleRipples(position + vec2(-dStep, -dStep));
    steps  *= strength;

    return normalize(vec3(-steps.x, dStep * 2.0, -steps.y));
}

void rainPuddles(vec3 scenePosition, vec3 geometricNormal, vec2 lightmapCoords, float porosity, inout float F0, inout float roughness, inout vec3 normal) {
    vec2 puddleCoords = ((scenePosition + cameraPosition).xz * 0.5 + 0.5) * (1.0 - RAIN_PUDDLES_SIZE * 0.01);

    float puddle  = saturate(FBM(puddleCoords, 3, 1.0) * 0.5 + 0.5);
          puddle *= pow2(quinticStep(0.0, 1.0, lightmapCoords.y));
          puddle *= quinticStep(0.89, 0.99, geometricNormal.y);
          puddle *= (1.0 - porosity);
          puddle *= wetness;
          puddle  = saturate(puddle);
          
    #if defined IS_IRIS
        puddle *= biome_may_rain;
    #endif

    vec3 surfaceNormal = mix(geometricNormal, getPuddleNormals(puddleCoords, 0.1), 0.035 * rainStrength);

    F0        = clamp(F0 + waterF0 * puddle, 0.0, mix(1.0, 229.5 * rcpMaxFloat8, float(F0 * maxFloat8 <= 229.5)));
    roughness = mix(roughness, 0.0, puddle);
    normal    = mix(normal, surfaceNormal, puddle);
}
