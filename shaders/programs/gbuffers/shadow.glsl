/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/include/common.glsl"

#if defined STAGE_VERTEX
    #define attribute in
    attribute vec4 at_tangent;
    attribute vec3 mc_Entity;
    attribute vec2 mc_midTexCoord;

    flat out int blockId;
    out vec2 texCoords;
    out vec3 worldPos;
    out vec4 vertexColor;
    out mat3 TBN;

    #include "/include/vertex/animation.glsl"

    void main() {
        texCoords   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
        vertexColor = gl_Color;
        blockId     = int((mc_Entity.x - 1000.0) + 0.25);

        vec3 viewShadowPos = transform(gl_ModelViewMatrix, gl_Vertex.xyz);
        worldPos           = (shadowModelViewInverse * vec4(viewShadowPos, 1.0)).xyz;

        #if WATER_CAUSTICS == 1
            vec3 geoNormal = normalize(gl_NormalMatrix * gl_Normal);
    	    vec3 tangent   = mat3(gbufferModelViewInverse) * (gl_NormalMatrix * (at_tangent.xyz / at_tangent.w));
		    TBN 		   = mat3(tangent, cross(tangent, geoNormal), geoNormal);
        #endif

	    #if ACCUMULATION_VELOCITY_WEIGHT == 0
            animate(worldPos, texCoords.y < mc_midTexCoord.y);
            gl_Position = transform(shadowModelView, worldPos).xyzz * diagonal4(gl_ProjectionMatrix) + gl_ProjectionMatrix[3];
	    #else
            gl_Position = ftransform();
        #endif

        worldPos       += cameraPosition;
        gl_Position.xyz = distortShadowSpace(gl_Position.xyz);
    }
    
#elif defined STAGE_FRAGMENT

    /* RENDERTARGETS: 0 */

    layout (location = 0) out vec4 color0;

    flat in int blockId;
    in vec2 texCoords;
    in vec3 worldPos;
    in vec4 vertexColor;
    in mat3 TBN;

    #if WATER_CAUSTICS == 1
        #include "/include/fragment/water.glsl"

        // https://medium.com/@evanwallace/rendering-realtime-caustics-in-webgl-2a99a29a0b2c
        // Thanks jakemichie97#7237 for the help!
        float waterCaustics(vec3 oldPos, vec3 normal) {
	        vec3 newPos = oldPos + refract(shadowLightVector, normal, 0.75) * 4.25;

            float oldArea = inversesqrt(lengthSqr(dFdx(oldPos)) * lengthSqr(dFdy(oldPos)));
            float newArea =        sqrt(lengthSqr(dFdx(newPos)) * lengthSqr(dFdy(newPos)));
	        return oldArea * newArea * 0.01;
        }
    #endif

    void main() {
        vec4 albedoTex = texture(colortex0, texCoords) * vertexColor;
        if(albedoTex.a < 0.102) discard;

        #if WHITE_WORLD == 1
	    	albedoTex.rgb = vec3(1.0);
        #endif

        #if WATER_CAUSTICS == 1
            float caustics = max0(waterCaustics(worldPos, TBN * getWaterNormals(worldPos, 3, 3.0)) * WATER_CAUSTICS_STRENGTH);
            color0         = mix(albedoTex, vec4(vec3(1.0 + caustics), -1.0), float(blockId == 1));
        #else
            color0 = mix(albedoTex, vec4(1.0, 1.0, 1.0, 0.0), float(blockId == 1));
        #endif
    }
#endif
