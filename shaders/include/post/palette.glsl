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

#if PALETTE == 1
    const int paletteSize = 7;

    // Smooth Polished Silver
    const vec3 palette[paletteSize] = vec3[paletteSize](
        vec3(0.000, 0.000, 0.000),
        vec3(0.157, 0.129, 0.122),
        vec3(0.290, 0.224, 0.239),
        vec3(0.404, 0.345, 0.298),
        vec3(0.690, 0.573, 0.655),
        vec3(0.949, 0.839, 0.886),
        vec3(1.000, 1.000, 1.000)
    );
#elif PALETTE == 2
    const int paletteSize = 8;

    // Hortensia Diamond
    const vec3 palette[paletteSize] = vec3[paletteSize](
        vec3(0.200, 0.169, 0.282),
        vec3(0.235, 0.251, 0.349),
        vec3(0.298, 0.345, 0.494),
        vec3(0.537, 0.467, 0.788),
        vec3(0.737, 0.553, 1.000),
        vec3(0.988, 0.608, 0.827),
        vec3(0.855, 0.729, 1.000),
        vec3(0.831, 0.980, 1.000)
    );
#elif PALETTE == 3
    const int paletteSize = 8;

    // St 8 Greenery
    const vec3 palette[paletteSize] = vec3[paletteSize](
        vec3(0.016, 0.051, 0.016),
        vec3(0.067, 0.149, 0.043),
        vec3(0.114, 0.251, 0.063),
        vec3(0.208, 0.400, 0.078),
        vec3(0.408, 0.600, 0.122),
        vec3(0.706, 0.800, 0.322),
        vec3(0.894, 0.949, 0.522),
        vec3(0.945, 0.949, 0.902)
    );
#elif PALETTE == 4
    const int paletteSize = 8;

    // Golden Flame
    const vec3 palette[paletteSize] = vec3[paletteSize](
        vec3(0.102, 0.102, 0.102),
        vec3(0.176, 0.110, 0.055),
        vec3(0.302, 0.176, 0.024),
        vec3(0.416, 0.235, 0.043),
        vec3(0.651, 0.412, 0.086),
        vec3(0.890, 0.655, 0.169),
        vec3(1.000, 0.882, 0.478),
        vec3(0.953, 0.929, 0.918)
    );
#elif PALETTE == 5
    const int paletteSize = 7;

    // Midnight Ablaze
    const vec3 palette[paletteSize] = vec3[paletteSize](
        vec3(0.075, 0.008, 0.031),
        vec3(0.122, 0.020, 0.063),
        vec3(0.192, 0.020, 0.118),
        vec3(0.275, 0.055, 0.169),
        vec3(0.486, 0.094, 0.235),
        vec3(0.835, 0.235, 0.416),
        vec3(1.000, 0.510, 0.455)
    );
#elif PALETTE == 6
    const int paletteSize = 8;

    // Custodian
    const vec3 palette[paletteSize] = vec3[paletteSize](
        vec3(0.169, 0.212, 0.204),
        vec3(0.278, 0.282, 0.282),
        vec3(0.431, 0.373, 0.322),
        vec3(0.635, 0.522, 0.424),
        vec3(0.627, 0.635, 0.580),
        vec3(0.863, 0.725, 0.627),
        vec3(0.953, 0.859, 0.776),
        vec3(1.000, 0.996, 0.996)
    );
#elif PALETTE == 7
    const int paletteSize = 8;

    // Tila-Alit
    const vec3 palette[paletteSize] = vec3[paletteSize](
        vec3(0.216, 0.102, 0.278),
        vec3(0.376, 0.145, 0.278),
        vec3(0.573, 0.227, 0.278),
        vec3(0.675, 0.314, 0.263),
        vec3(0.765, 0.427, 0.267),
        vec3(0.890, 0.580, 0.329),
        vec3(0.906, 0.690, 0.424),
        vec3(0.969, 0.925, 0.682)
    );
#elif PALETTE == 8
    const int paletteSize = 8;

    // Gothic Bit
    const vec3 palette[paletteSize] = vec3[paletteSize](
        vec3(0.055, 0.055, 0.071),
        vec3(0.102, 0.102, 0.141),
        vec3(0.200, 0.200, 0.275),
        vec3(0.325, 0.325, 0.451),
        vec3(0.502, 0.502, 0.643),
        vec3(0.651, 0.651, 0.749),
        vec3(0.757, 0.757, 0.824),
        vec3(0.902, 0.902, 0.925)
    );
#elif PALETTE == 9
    const int paletteSize = 8;

    // Halloween Candy
    const vec3 palette[paletteSize] = vec3[paletteSize](
        vec3(0.000, 0.067, 0.133),
        vec3(0.133, 0.067, 0.333),
        vec3(0.467, 0.067, 0.533),
        vec3(0.800 ,0.133, 0.133),
        vec3(0.800, 0.533, 0.067),
        vec3(0.267, 0.800, 0.267),
        vec3(0.867, 0.933, 0.333),
        vec3(0.933, 0.867, 1.000)
    );
#elif PALETTE == 10
    const int paletteSize = 8;

    // Berry Nebula
    const vec3 palette[paletteSize] = vec3[paletteSize](
        vec3(0.051, 0.000, 0.102),
        vec3(0.180, 0.039, 0.188),
        vec3(0.310, 0.078, 0.275),
        vec3(0.435, 0.114, 0.361),
        vec3(0.431, 0.318, 0.506),
        vec3(0.427, 0.522, 0.647),
        vec3(0.424, 0.725, 0.788),
        vec3(0.424, 0.929, 0.929)
    );
#endif

void applyColorPalette(inout vec3 color) {
    float index  = luminance(color) * (paletteSize - 1);
    float dither = float(fract(index) > bayer8(gl_FragCoord.xy));

    index = floor(index);

    vec3 c1 = palette[min(int(index)    , paletteSize - 1)];
    vec3 c2 = palette[min(int(index) + 1, paletteSize - 1)];

    color = mix(c1, c2, dither);
}
