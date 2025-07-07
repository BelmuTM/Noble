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
    [Credits]:
        Inigo Quilez - palette function for thin film (https://iquilezles.org/articles/palettes/)
    
    [References]:
        gelami. (2023). Lens Flare Post-Processing. https://www.shadertoy.com/view/mtVSRd
*/

vec3 palette(float x) {
    return 0.5 + 0.5 * cos(TAU * (x + vec3(0, 0.25, 0.5)));
}

float ghostSpacing(int i) {
    float x = i / float(LENS_FLARES_GHOSTS - 1) - 0.5;

    float distribution = 1.0 - gaussianDistribution1D(x, LENS_FLARES_GHOSTS_SPACING_SIGMA);

    return mix(LENS_FLARES_GHOSTS_MIN_SPACING, LENS_FLARES_GHOSTS_MAX_SPACING, distribution);
}

void lensFlares(inout vec3 color, vec2 coords) {
    const float attenuationFactor = 1e-3;

    vec3 flares = vec3(0.0);

    /* Ghosts */

    vec2 invertedCoords = 1.0 - coords;
    vec2 ghostDirection = 0.5 - invertedCoords;

    #if LENS_FLARES_GHOSTS_ABERRATION == 1
        float caOffset = texelSize.y * LENS_FLARES_GHOSTS_ABERRATION_STRENGTH;
    #else
        float caOffset = 0.0;
    #endif

    const float k = length(vec2(0.5));
          float d = length(ghostDirection) / k;

    float totalWeight = 0.0;

    for (int i = 0; i < LENS_FLARES_GHOSTS; i++) {
        vec2 ghostOffset = ghostDirection * i * ghostSpacing(i);
        vec2 ghostCoords = invertedCoords + ghostOffset;

        float weight = pow(max0(1.0 - d), 8.0);

        vec3 ghostSample = vec3(
            texture(IRRADIANCE_BUFFER, fract(ghostCoords - ghostOffset * caOffset) * 0.5).r,
            texture(IRRADIANCE_BUFFER, fract(ghostCoords                         ) * 0.5).g,
            texture(IRRADIANCE_BUFFER, fract(ghostCoords + ghostOffset * caOffset) * 0.5).b
        );

        #if LENS_FLARES_GHOSTS_THIN_FILM == 1
            float thinFilmNoise = texture(noisetex, fract(ghostCoords) * 0.3).b;
            vec3  thinFilm      = palette(thinFilmNoise * 3.0);

            ghostSample *= thinFilm;
        #endif

        flares      += ghostSample * weight;
        totalWeight += weight;
    }

    flares /= totalWeight;

    /* Halo */

    #if LENS_FLARES_HALO == 1

        const vec2 stretch = vec2(LENS_FLARES_HALO_STRETCH_Y, LENS_FLARES_HALO_STRETCH_X);

        vec2 haloCoords    = (invertedCoords - 0.5) * vec2(aspectRatio, 1.0) * stretch + 0.5;
        vec2 haloDirection = normalize(0.5 - haloCoords) * LENS_FLARES_HALO_RADIUS;

        float dist   = length(0.5 - (haloCoords + haloDirection)) / k;
        float weight = quinticStep(0.8, 1.0, 1.0 - dist);

        if (weight > 0.0) {
            vec3 haloSample = vec3(
                texture(IRRADIANCE_BUFFER, (haloCoords + haloDirection * 1.01) * 0.5).r,
                texture(IRRADIANCE_BUFFER, (haloCoords + haloDirection       ) * 0.5).g,
                texture(IRRADIANCE_BUFFER, (haloCoords + haloDirection * 0.99) * 0.5).b
            );

            flares += haloSample * weight;
        }

    #endif

    color += flares * attenuationFactor * LENS_FLARES_STRENGTH;
}
