/***********************************************/
/*          Copyright (C) 2023 Belmu           */
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

const int colortex0Format  = RGBA16F;   // Main
const int colortex1Format  = RGBA32UI;  // Gbuffer data
const int colortex2Format  = RGBA8F;    // Reflections
const int colortex3Format  = RGBA16F;   // Geometric normals, shadowmap, bloom
const int colortex4Format  = RGBA16F;   // Deferred Lighting
const int colortex5Format  = RGBA32F;   // Irradiance, clouds shadows
const int colortex6Format  = RGB16F;    // Atmosphere
const int colortex7Format  = RGBA16F;   // Clouds
const int colortex8Format  = RGBA16F;   // History
const int colortex9Format  = RG32UI;    // First bounce indirect & direct
const int colortex10Format = RG16F;     // Variance, previous depth
const int colortex11Format = RG32UI;    // Fog
const int colortex12Format = RGBA16F;   // Ambient occlusion
const int colortex15Format = RGBA16F;   // Gbuffer data

const bool colortex0Clear  = false;
const bool colortex2Clear  = false;
const bool colortex4Clear  = false;
const bool colortex6Clear  = false;
const bool colortex7Clear  = false;
const bool colortex8Clear  = false;
const bool colortex9Clear  = false;
const bool colortex10Clear = false;
const bool colortex12Clear = false;
*/
