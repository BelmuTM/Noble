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

// Perspective uniforms for chunk loader mods support (Distant Horizons, Voxy)

#if defined DISTANT_HORIZONS

    uniform float dhNearPlane;
    uniform float dhFarPlane;

    uniform sampler2D dhDepthTex0;
    uniform sampler2D dhDepthTex1;

    uniform mat4 dhProjection;
    uniform mat4 dhProjectionInverse;
    uniform mat4 dhProjectionPrevious;

    uniform int dhRenderDistance;

    #define nearPlane near
    #define farPlane  dhRenderDistance

    #define modProjection         dhProjection
    #define modProjectionInverse  dhProjectionInverse
    #define modProjectionPrevious gbufferPreviousProjection

    #define modDepthTex0 dhDepthTex0
    #define modDepthTex1 dhDepthTex1

#elif defined VOXY

    uniform sampler2D vxDepthTexOpaque;
    uniform sampler2D vxDepthTexTrans;

    uniform mat4 vxProj;
    uniform mat4 vxProjInv;
    uniform mat4 vxProjPrev;

    uniform int vxRenderDistance;

    #define nearPlane near

    float farPlane = float(vxRenderDistance * 4);

    #define modProjection         vxProj
    #define modProjectionInverse  vxProjInv
    #define modProjectionPrevious vxProjPrev

    #define modDepthTex0 vxDepthTexTrans
    #define modDepthTex1 vxDepthTexOpaque

#else

    #define nearPlane near
    #define farPlane  far

    #define modProjection         gbufferProjection
    #define modProjectionInverse  gbufferProjectionInverse
    #define modProjectionPrevious gbufferPreviousProjection

    #define modDepthTex0 depthtex0
    #define modDepthTex1 depthtex1

#endif

#if defined CHUNK_LOD_MOD_ENABLED

    // https://shaderlabs.org/wiki/Shader_Tricks#Constructing_Perspective_Projection_Matrices

    mat4 combinedProjection = mat4(
        // Row 1
        gbufferProjection[0][0],
        0.0,
        0.0,
        0.0,

        // Row 2
        0.0,
        gbufferProjection[1][1],
        0.0,
        0.0,

        // Row 3
        gbufferProjection[2][0],
        gbufferProjection[2][1],
        (farPlane + nearPlane) / (nearPlane - farPlane),
        -1.0,

        // Row 4
        0.0,
        0.0,
        (2.0 * farPlane * nearPlane) / (nearPlane - farPlane),
        0.0
    );

    mat4 combinedProjectionInverse = mat4(
        // Row 1
        gbufferProjectionInverse[0][0],
        0.0,
        0.0,
        0.0,

        // Row 2
        0.0,
        gbufferProjectionInverse[1][1],
        0.0,
        0.0,
        
        // Row 3
        0.0,
        0.0,
        0.0,
        -(farPlane - nearPlane) / (2.0 * farPlane * nearPlane),

        // Row 4
        gbufferProjectionInverse[3][0],
        gbufferProjectionInverse[3][1],
        -1.0,
        (farPlane + nearPlane) / (2.0 * farPlane * nearPlane)
        
    );

    #define projectionMatrix        combinedProjection
    #define projectionInverseMatrix combinedProjectionInverse

    #define depthBuffer0 COMBINED_DEPTH0_BUFFER
    #define depthBuffer1 COMBINED_DEPTH1_BUFFER

#else

    #define projectionMatrix        gbufferProjection
    #define projectionInverseMatrix gbufferProjectionInverse

    #define depthBuffer0 depthtex0
    #define depthBuffer1 depthtex1

#endif
