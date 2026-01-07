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

#if AO == 1 || GI == 1
    const float ambientOcclusionLevel = 0.0;
#else
    const float ambientOcclusionLevel = 1.0;
#endif

/*

// ============================================================================
// SHADOW MAP TEXTURES / SHADOW BUFFER
// ============================================================================

const int shadowcolor0Format = RGBA16F;

const int colortex3Format = RGBA16F;                // Shadow map

// ============================================================================
// MAIN COLOR / GBUFFERS
// ============================================================================

const int  colortex0Format = RGBA16F;               // Main color
const bool colortex0Clear  = false;

const int  colortex1Format = RGBA32UI;              // GBuffer data:
                                                    // [R] parallax self shadowing | lightmap XY coordinates
                                                    // [G] material AO | emission | F0 | subsurface
                                                    // [B] texture albedo RGB | roughness
                                                    // [A] encoded XY material normals

const int colortex15Format = RGBA8;                 // Alpha blended GBuffer data (albedo)

const int colortex13Format = R32F;                  // Depth tiles

// ============================================================================
// REFLECTIONS
// ============================================================================

#if REFLECTIONS > 0
    const int  colortex2Format = RGBA16F;           // Reflections
    const bool colortex2Clear  = false;
#endif

// ============================================================================
// DEFERRED LIGHTING / GLOBAL ILLUMINATION
// ============================================================================

#if RENDER_MODE == 0
    const int colortex4Format = RGBA16F;            // Deferred lighting
#else
    const int colortex4Format = RGBA32F;            // Global illumination buffer
#endif

const bool colortex4Clear = false;

// ============================================================================
// IRRADIANCE / CLOUDS SHADOWS / BLOOM
// ============================================================================

const int colortex5Format = RGBA32F;                // Irradiance | Clouds shadows | Bloom

// ============================================================================
// ATMOSPHERE
// ============================================================================

const int  colortex6Format = R11F_G11F_B10F;        // Atmosphere
const bool colortex6Clear  = false;

// ============================================================================
// CLOUDS
// ============================================================================

#if CLOUDS_LAYER0_ENABLED == 1 || CLOUDS_LAYER1_ENABLED == 1
    const int  colortex7Format = RGBA16F;           // Clouds
    const bool colortex7Clear  = false;
#endif

#if CLOUDMAP == 1
    const int colortex14Format = R11F_G11F_B10F;    // Cloud map (low resolution)
#endif

// ============================================================================
// TEMPORAL DATA / HISTORY
// ============================================================================

const int  colortex8Format = RGBA16F;               // [RGB] Previous color | [A] Average luminance
const bool colortex8Clear  = false;

#if RENDER_MODE == 0 && GI == 1 && TEMPORAL_ACCUMULATION == 1 && ATROUS_FILTER == 1
    const int colortex10Format = RGBA16F;           // [R] Previous frame depth | [GBA] Moments
#else
    const int colortex10Format = R16F;              // Previous frame Depth
#endif
const bool colortex10Clear = false;

// ============================================================================
// FOG
// ============================================================================

const int colortex11Format = RG32UI;                // Fog

// ============================================================================
// AMBIENT OCCLUSION
// ============================================================================
#if AO == 1
    const int  colortex12Format = RGB16F;           // Ambient occlusion
    const bool colortex12Clear  = false;
#endif

*/
