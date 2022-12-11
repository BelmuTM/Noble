/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#if AO == 1 || GI == 1
     const float ambientOcclusionLevel = 0.0;
#else
     const float ambientOcclusionLevel = 1.0;
#endif

/*
const int shadowcolor0Format = RGBA16F;
const int shadowcolor1Format = RGBA8;

const int colortex0Format  = RGBA16F;   // Clouds
const int colortex1Format  = RGBA32UI;  // Gbuffers Data
const int colortex2Format  = RGBA16F;   // Geometric normals, POM selfshadowing and reflections
const int colortex3Format  = RGBA16F;   // Shadowmap, Bloom
const int colortex4Format  = RGBA32F;   // Main Buffer 0
const int colortex5Format  = RGBA32F;   // Main Buffer 1
const int colortex6Format  = RGB32F;    // Direct & Indirect Illuminances
const int colortex8Format  = RGBA16F;   // History Buffer
const int colortex9Format  = RGBA32F;   // Direct PT
const int colortex10Format = RGBA32F;   // Indirect PT
const int colortex11Format = RGBA32F;   // Moments
const int colortex12Format = RGB16F;    // Sky
const int colortex13Format = RGBA16F;   // Translucents

const bool colortex0Clear  = false;
const bool colortex5Clear  = false;
const bool colortex8Clear  = false;
const bool colortex9Clear  = false;
const bool colortex10Clear = false;
const bool colortex11Clear = false;
const bool colortex12Clear = false;
const bool colortex13Clear = false;
*/
