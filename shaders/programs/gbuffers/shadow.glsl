/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/settings.glsl"
#include "/include/taau_scale.glsl"

#include "/include/common.glsl"

#if defined STAGE_VERTEX
    #define attribute in
    attribute vec4 at_tangent;
    attribute vec3 mc_Entity;
    attribute vec2 mc_midTexCoord;

    flat out int blockId;
    out vec2 textureCoords;
    out vec3 worldPosition;
    out vec4 vertexColor;
    out mat3 tbn;

    #include "/include/vertex/animation.glsl"

    void main() {
        textureCoords = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
        vertexColor   = gl_Color;
        blockId       = int((mc_Entity.x - 1000.0) + 0.25);

        vec3 viewShadowPos = transform(gl_ModelViewMatrix, gl_Vertex.xyz);
             worldPosition = transform(shadowModelViewInverse, viewShadowPos);

        #if WATER_CAUSTICS == 1
    	    tbn[2] = mat3(shadowModelViewInverse) * normalize(gl_NormalMatrix * gl_Normal);
    	    tbn[0] = mat3(shadowModelViewInverse) * normalize(gl_NormalMatrix * at_tangent.xyz);
		    tbn[1] = cross(tbn[0], tbn[2]) * sign(at_tangent.w);
        #endif

	    #if RENDER_MODE == 0 && WAVING_PLANTS == 1
            animate(worldPosition, textureCoords.y < mc_midTexCoord.y, getSkylightFalloff(gl_MultiTexCoord1.y * rcp(240.0)));
            gl_Position = transform(shadowModelView, worldPosition).xyzz * diagonal4(gl_ProjectionMatrix) + gl_ProjectionMatrix[3];
	    #else
            gl_Position = ftransform();
        #endif

        worldPosition  += cameraPosition;
        gl_Position.xyz = distortShadowSpace(gl_Position.xyz);
    }
    
#elif defined STAGE_FRAGMENT

    /* RENDERTARGETS: 0 */

    layout (location = 0) out vec4 color0;

    flat in int blockId;
    in vec2 textureCoords;
    in vec3 worldPosition;
    in vec4 vertexColor;
    in mat3 tbn;

    #if WATER_CAUSTICS == 1
        #include "/include/fragment/gerstner.glsl"

        // https://medium.com/@evanwallace/rendering-realtime-caustics-in-webgl-2a99a29a0b2c
        float waterCaustics(vec3 oldPos, vec3 normal) {
	        vec3 newPos = oldPos + refract(shadowLightVector, normal, 0.75) * 2.0;

            float oldArea = length(dFdx(oldPos)) * length(dFdy(oldPos));
            float newArea = length(dFdx(newPos)) * length(dFdy(newPos));
	        return oldArea / newArea * 0.2;
        }
    #endif

    void main() {
        vec4 albedoTex = texture(tex, textureCoords) * vertexColor;
        if(albedoTex.a < 0.102) discard;

        #if WHITE_WORLD == 1
	    	albedoTex.rgb = vec3(1.0);
        #endif

        color0 = albedoTex;

        if(blockId == WATER_ID) {
            color0.rgb = vec3(1.0);

            #if WATER_CAUSTICS == 1
                vec3  waterNormals = normalize(tbn * getWaterNormals(worldPosition, WATER_OCTAVES));
                float caustics     = waterCaustics(worldPosition, waterNormals) * WATER_CAUSTICS_STRENGTH;

                color0.rgb += caustics;
            #endif
        }
    }
#endif
