/***********************************************/
/*          Copyright (C) 2024 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/settings.glsl"
#include "/include/taau_scale.glsl"

#include "/include/common.glsl"

#if defined STAGE_VERTEX

    #define attribute in
    attribute vec4 at_tangent;
    attribute vec3 at_midBlock;
    attribute vec3 mc_Entity;
    attribute vec2 mc_midTexCoord;

    flat out int blockId;
    out vec2 textureCoords;
    out vec3 worldPosition;
    out vec4 vertexColor;

    #if RENDER_MODE == 0 && WAVING_PLANTS == 1
        uniform float rcp240;
    #endif

    #include "/include/vertex/animation.glsl"

    void main() {
        textureCoords = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
        vertexColor   = gl_Color;
        blockId       = int((mc_Entity.x - 1000.0) + 0.25);

        vec3 viewShadowPosition = (gl_ModelViewMatrix * gl_Vertex).xyz;
             worldPosition      = transform(shadowModelViewInverse, viewShadowPosition);

	    #if RENDER_MODE == 0 && WAVING_PLANTS == 1
            animate(worldPosition, textureCoords.y < mc_midTexCoord.y, getSkylightFalloff(gl_MultiTexCoord1.y * rcp240));
            gl_Position = project(gl_ProjectionMatrix, transform(shadowModelView, worldPosition));
	    #else
            gl_Position = ftransform();
        #endif

        worldPosition  += cameraPosition;
        gl_Position.xyz = distortShadowSpace(gl_Position.xyz);
    }
    
#elif defined STAGE_FRAGMENT

    /* RENDERTARGETS: 0 */

    layout (location = 0) out vec4 shadowmap;

    flat in int blockId;
    in vec2 textureCoords;
    in vec3 worldPosition;
    in vec4 vertexColor;

    #if WATER_CAUSTICS == 1
        #include "/include/fragment/gerstner.glsl"

        // https://medium.com/@evanwallace/rendering-realtime-caustics-in-webgl-2a99a29a0b2c
        float waterCaustics(vec3 oldPos, vec3 normal) {
	        vec3 newPos = oldPos + refract(shadowLightVector, normal, airIOR / 1.333);

            float oldArea = length(dFdx(oldPos)) * length(dFdy(oldPos));
            float newArea = length(dFdx(newPos)) * length(dFdy(newPos));
            
	        return saturate(fastInvSqrtN1(oldArea / newArea) * 0.2);
        }
    #endif

    void main() {
        vec4 albedoTex = texture(tex, textureCoords);
        albedoTex.rgb *= vertexColor.rgb;

        if(albedoTex.a < 0.102) discard;

        #if WHITE_WORLD == 1
	    	albedoTex.rgb = vec3(1.0);
        #endif

        shadowmap = albedoTex;

        if(blockId == WATER_ID) {
            shadowmap.rgb = vec3(1.0);

            #if WATER_CAUSTICS == 1
                vec3  waterNormals = getWaterNormals(worldPosition, 1.0, 3);
                float caustics     = waterCaustics(worldPosition, waterNormals) * WATER_CAUSTICS_STRENGTH;

                shadowmap.rgb += max0(caustics);
            #endif
        }
    }
    
#endif
