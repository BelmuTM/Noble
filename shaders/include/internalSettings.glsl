/***********************************************/
/*          Copyright (C) 2024 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#if AO == 1 || GI == 1
     const float ambientOcclusionLevel = 0.0;
#else
     const float ambientOcclusionLevel = 1.0;
#endif

/*
const int  shadowcolor0Format      = RGBA16F;
const bool shadowHardwareFiltering = false;

const int colortex0Format       = RGBA16F;   // Main
const int colortex1Format       = RGBA32UI;  // Gbuffer data

#if REFLECTIONS == 1
     const int colortex2Format  = RGB16F;    // Reflections
#endif

const int colortex3Format       = RGBA16F;        // Geometric normals, shadowmap, bloom
const int colortex4Format       = RGBA16F;        // Deferred Lighting
const int colortex5Format       = RGBA16F;        // Irradiance, clouds shadows
const int colortex6Format       = R11F_G11F_B10F; // Atmosphere

const vec4 colortex3ClearColor = vec4(0.0, 0.0, 0.0, 0.0);

#if CLOUDS_LAYER0_ENABLED == 1 || CLOUDS_LAYER1_ENABLED == 1
     const int colortex7Format  = R11F_G11F_B10F; // Clouds
     const bool colortex7Clear  = false;
#endif

const int colortex8Format       = RGBA16F;   // History

#if GI == 1
     const int colortex9Format  = RGB16F;    // Direct lighting
     const int colortex10Format = RGBA32F;   // Moments
#else
     const int colortex10Format = RGBA16F;   // Previous Depth
#endif

const bool colortex10Clear      = false;

const int colortex11Format      = RG32UI;    // Fog

#if AO == 1
     const int colortex12Format = RGB16F;    // Ambient occlusion
     const bool colortex12Clear = false;
#endif

const int colortex13Format      = RGBA16F;    // Deferred

const int colortex15Format      = RGBA16F;   // Gbuffer data

const bool colortex0Clear       = false;
const bool colortex4Clear       = false;
const bool colortex6Clear       = false;
const bool colortex8Clear       = false;
*/
