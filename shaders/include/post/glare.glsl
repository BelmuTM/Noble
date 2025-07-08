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

/*
    [References]:
        gelami. (2023). Lens Flare Post-Processing. https://www.shadertoy.com/view/mtVSRd
*/

const float inv_sqrt2 = 1.0 / sqrt(2.0);

const vec2 bladeDirections[4] = vec2[4](
    vec2( inv_sqrt2, inv_sqrt2),
    vec2(-inv_sqrt2, inv_sqrt2),
    vec2( 1.0      , 0.0      ),
    vec2( 0.0      , 1.0      )
);

void glare(inout vec3 color, vec2 coords) {
    const float sigma = GLARE_STEPS * GLARE_BLADES_SIZE * 0.45;

    float angle   = radians(GLARE_BLADES_ANGLE);
    mat2 rotation = mat2(cos(angle), -sin(angle), sin(angle), cos(angle));

    vec3 glare = vec3(0.0);
    float totalWeight = 0.0;
    
    for (int i = -GLARE_STEPS; i <= GLARE_STEPS; i++) {
        float d = float(i) * GLARE_BLADES_SIZE;
        
        float weight = gaussianDistribution1D(d, sigma);

        #if GLARE_THIN_FILM == 1
            vec3 thinFilm = paletteFunction((float(i) / GLARE_STEPS) * 3.0) * 0.9 + 0.1;
        #else
            vec3 thinFilm = vec3(1.0);
        #endif

        vec2 scale = texelSize * d;

        #if GLARE_BLADES >= 1
            glare += texture(IRRADIANCE_BUFFER, (coords + bladeDirections[0] * rotation * scale) * 0.5).rgb * thinFilm * weight;
        #endif

        #if GLARE_BLADES >= 2
            glare += texture(IRRADIANCE_BUFFER, (coords + bladeDirections[1] * rotation * scale) * 0.5).rgb * thinFilm * weight;
        #endif

        #if GLARE_BLADES >= 3
            glare += texture(IRRADIANCE_BUFFER, (coords + bladeDirections[2] * rotation * scale) * 0.5).rgb * thinFilm * weight;
        #endif

        #if GLARE_BLADES >= 4
            glare += texture(IRRADIANCE_BUFFER, (coords + bladeDirections[3] * rotation * scale) * 0.5).rgb * thinFilm * weight;
        #endif

        totalWeight += weight;
    }
    
    color += (glare / totalWeight) * 0.1 * GLARE_STRENGTH;
}
