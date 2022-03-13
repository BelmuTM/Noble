/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#if defined STAGE_VERTEX

    #include "/include/utility/math.glsl"
    #include "/include/utility/transforms.glsl"

    #define attribute in
    attribute vec4 at_tangent;
    attribute vec3 mc_Entity;

    flat out int blockId;
    out vec2 texCoords;
    out vec3 viewPos;
    out vec4 vertexColor;
    out mat3 TBN;

    void main() {
        texCoords   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
        vertexColor = gl_Color;
        blockId     = int((mc_Entity.x - 1000.0) + 0.25);

        vec3 normal = normalize(gl_NormalMatrix * gl_Normal);
    	viewPos     = transMAD(gl_ModelViewMatrix, gl_Vertex.xyz);

        vec3 tangent   = normalize(gl_NormalMatrix * at_tangent.xyz);
        vec3 bitangent = normalize(cross(tangent, normal) * sign(at_tangent.w));
	    TBN 		   = mat3(tangent, bitangent, normal);

        gl_Position     = ftransform();
        gl_Position.xyz = distortShadowSpace(gl_Position.xyz);
    }
    
#elif defined STAGE_FRAGMENT

    /* RENDERTARGETS: 0,1 */

    layout (location = 0) out vec4 color0;
    layout (location = 1) out vec4 color1;

    flat in int blockId;
    in vec2 texCoords;
    in vec3 viewPos;
    in vec4 vertexColor;
    in mat3 TBN;

    #include "/include/fragment/water.glsl"

    // https://medium.com/@evanwallace/rendering-realtime-caustics-in-webgl-2a99a29a0b2c
    float waterCaustics(vec3 oldPos, vec3 normal) {
	    vec3 lightDir = mat3(shadowModelView) * sceneShadowDir;
	    vec3 newPos   = oldPos + refract(lightDir, normal, 1.0 / 1.333) * 1.5;

	    float oldArea = length(dFdy(oldPos)) * length(dFdy(oldPos));
	    float newArea = length(dFdy(newPos)) * length(dFdy(newPos));

	    return oldArea / newArea * 0.2;
    }

    void main() {
        vec4 albedoTex = texture(colortex0, texCoords);
        if(albedoTex.a < 0.102) discard;
        
        color0 = albedoTex;
        color1.r = blockId == 1 ? waterCaustics(transMAD(shadowModelViewInverse, viewPos), TBN * getWaveNormals(viewToWorld(viewPos))) : 0.0;
    }
#endif
