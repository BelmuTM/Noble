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

#if AO == 1 || GI == 1
     const float ambientOcclusionLevel = 0.0;
#else
     const float ambientOcclusionLevel = 1.0;
#endif

/*
const int  shadowcolor0Format      = RGBA16F;
const bool shadowHardwareFiltering = false;

const int  colortex0Format         = RGBA16F;           // Main
const bool colortex0Clear          = false;
const int  colortex1Format         = RGBA32UI;          // Gbuffer data

#if REFLECTIONS > 0
    const int  colortex2Format     = RGBA16F;           // Reflections
    const bool colortex2Clear      = false;
#endif

const int  colortex3Format         = RGBA16F;           // Shadowmap
const int  colortex4Format         = RGBA16F;           // Deferred Lighting
const bool colortex4Clear          = false;
const int  colortex5Format         = RGBA32F;           // Irradiance | Clouds Shadows | Bloom
const int  colortex6Format         = R11F_G11F_B10F;    // Atmosphere
const bool colortex6Clear          = false;

#if CLOUDS_LAYER0_ENABLED == 1 || CLOUDS_LAYER1_ENABLED == 1
    const int colortex7Format      = RGBA16F;           // Clouds
    const bool colortex7Clear      = false;
#endif

const int  colortex8Format         = RGBA16F;           // History
const bool colortex8Clear          = false;

#if RENDER_MODE == 0 && GI == 1 && TEMPORAL_ACCUMULATION == 1 && ATROUS_FILTER == 1
    const int colortex10Format     = RGBA16F;           // Moments | Previous Frame Depth
#else
    const int colortex10Format     = R16F;              // Previous Frame Depth
#endif
const bool colortex10Clear         = false;

const int colortex11Format         = RG32UI;            // Fog

#if AO == 1
    const int  colortex12Format    = RGB16F;            // Ambient occlusion
    const bool colortex12Clear     = false;
#endif

#if CLOUDMAP == 1
    const int colortex14Format     = R11F_G11F_B10F;    // Cloudmap
#endif

const int colortex15Format         = RGBA8;             // Gbuffer data
*/
