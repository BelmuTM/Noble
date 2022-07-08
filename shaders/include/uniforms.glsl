/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

uniform vec3 shadowLightPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 cameraPosition;
uniform vec3 upPosition;
uniform vec3 skyColor;

uniform vec2 viewSize;
uniform vec2 pixelSize;

uniform int framemod;
uniform int frameCounter;
uniform float frameTime;
uniform float frameTimeCounter;
uniform float centerDepthSmooth;
uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float aspectRatio;
uniform int isEyeInWater;
uniform int hideGUI;
uniform float rainStrength;
uniform float wetness;
uniform float eyeAltitude;
uniform float sunAngle;

uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D colortex0;
uniform usampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D colortex7;
uniform sampler2D colortex8;
uniform sampler2D colortex9;
uniform sampler2D colortex10;
uniform sampler2D colortex11;
uniform sampler2D colortex12;
uniform sampler3D colortex13;
uniform sampler3D colortex14;
uniform sampler2D colortex15;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler3D depthtex2;
uniform sampler2D noisetex;

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

uniform vec3 previousCameraPosition;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;

const int noiseRes  = 256;
const float airIOR  = 1.00029;
const float waterF0 = 0.02;

// Maximum values for X amount of bits (2^x - 1)
const float maxVal8  = 255.0;
const float maxVal16 = 65535.0;

vec3 shadowDir      = shadowLightPosition * 0.01;
vec3 sceneShadowDir = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition + gbufferModelViewInverse[3].xyz);
vec3 sceneSunDir    = normalize(mat3(gbufferModelViewInverse) * sunPosition         + gbufferModelViewInverse[3].xyz);
vec3 sceneMoonDir   = normalize(mat3(gbufferModelViewInverse) * moonPosition        + gbufferModelViewInverse[3].xyz);
