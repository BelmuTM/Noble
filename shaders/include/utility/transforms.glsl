/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

//////////////////////////////////////////////////////////
/*--------------- MATRICES OPERATIONS ------------------*/
//////////////////////////////////////////////////////////

vec2 diagonal2(mat4 mat) { return vec2(mat[0].x, mat[1].y); 		   }
vec3 diagonal3(mat4 mat) { return vec3(mat[0].x, mat[1].y, mat[2].z);  }
vec4 diagonal4(mat4 mat) { return vec4(mat[0].x, mat[1].y, mat[2].zw); }

vec2 projectOrtho(mat4 mat, vec2 v) { return diagonal2(mat) * v + mat[3].xy;  }
vec3 projectOrtho(mat4 mat, vec3 v) { return diagonal3(mat) * v + mat[3].xyz; }
vec3 transform   (mat4 mat, vec3 v) { return mat3(mat)      * v + mat[3].xyz; }

//////////////////////////////////////////////////////////
/*--------------------- SHADOWS ------------------------*/
//////////////////////////////////////////////////////////

float getDistortionFactor(vec2 coords) {
	return cubeLength(coords) * SHADOW_DISTORTION + (1.0 - SHADOW_DISTORTION);
}

vec2 distortShadowSpace(vec2 position) {
	return position / getDistortionFactor(position.xy);
}

vec3 distortShadowSpace(vec3 position) {
	position.xy = distortShadowSpace(position.xy);
	position.z *= SHADOW_DEPTH_STRETCH;
	return position;
}

//////////////////////////////////////////////////////////
/*----------------- CLOUDS SHADOWS ---------------------*/
//////////////////////////////////////////////////////////

#if defined WORLD_OVERWORLD && CLOUDS_SHADOWS == 1 && PRIMARY_CLOUDS == 1
    vec3 getCloudsShadowPos(vec2 coords) {
        coords *= rcp(CLOUDS_SHADOWS_RESOLUTION);
        coords  = coords * 2.0 - 1.0;
        coords /= 1.0 - length(coords.xy);

        return transform(shadowModelViewInverse, vec3(coords * far, 1.0)) + atmosphereRayPosition;
    }

    float getCloudsShadows(vec3 position) {
        position     = transform(shadowModelView, position) / far;
        position.xy /= 1.0 + length(position.xy);
        position.xy  = position.xy * 0.5 + 0.5;

        return texture(colortex6, position.xy * CLOUDS_SHADOWS_RESOLUTION * pixelSize).a;
    }
#endif

//////////////////////////////////////////////////////////
/*--------------- SPACE CONVERSIONS --------------------*/
//////////////////////////////////////////////////////////

vec3 screenToView(vec3 screenPos) {
	screenPos = screenPos * 2.0 - 1.0;
	return projectOrtho(gbufferProjectionInverse, screenPos) / (gbufferProjectionInverse[2].w * screenPos.z + gbufferProjectionInverse[3].w);
}

vec3 viewToScreen(vec3 viewPos) {
	return (projectOrtho(gbufferProjection, viewPos) / -viewPos.z) * 0.5 + 0.5;
}

vec3 sceneToView(vec3 scenePos) {
	return transform(gbufferModelView, scenePos);
}

vec3 viewToScene(vec3 viewPos) {
	return transform(gbufferModelViewInverse, viewPos);
}

vec3 worldToView(vec3 worldPos) {
	return mat3(gbufferModelView) * (worldPos - cameraPosition);
}

vec3 viewToWorld(vec3 viewPos) {
	return viewToScene(viewPos) + cameraPosition;
}

mat3 constructViewTBN(vec3 viewNormal) {
	vec3 tangent = normalize(cross(gbufferModelViewInverse[1].xyz, viewNormal));
	return mat3(tangent, cross(tangent, viewNormal), viewNormal);
}

vec3 getViewPos0(vec2 coords) {
    return screenToView(vec3(coords, texture(depthtex0, coords).r));
}

vec3 getViewPos1(vec2 coords) {
    return screenToView(vec3(coords, texture(depthtex1, coords).r));
}

// https://wiki.shaderlabs.org/wiki/Shader_tricks#Linearizing_depth
float linearizeDepth(float depth) {
    depth = depth * 2.0 - 1.0;
    return 2.0 * far * near / (far + near - depth * (far - near));
}

float linearizeDepthFast(float depth) {
	return (near * far) / (depth * (near - far) + far);
}

//////////////////////////////////////////////////////////
/*------------------ REPROJECTION ----------------------*/
//////////////////////////////////////////////////////////

vec3 getVelocity(vec3 currPos) {
    vec3 cameraOffset = (cameraPosition - previousCameraPosition) * float(linearizeDepthFast(currPos.z) >= MC_HAND_DEPTH);

    vec3 prevPos = transform(gbufferPreviousModelView, cameraOffset + viewToScene(screenToView(currPos)));
         prevPos = (projectOrtho(gbufferPreviousProjection, prevPos) / -prevPos.z) * 0.5 + 0.5;

    return currPos - prevPos;
}

vec3 reproject(vec2 coords){
    vec3 position = viewToScene(getViewPos0(coords));

	vec3 cameraOffset = (cameraPosition - previousCameraPosition) * float(linearizeDepthFast(texture(depthtex0, coords).r) >= MC_HAND_DEPTH);

    position = transform(gbufferPreviousModelView, cameraOffset + viewToScene(getViewPos0(coords)));
    return (projectOrtho(gbufferPreviousProjection, position) / -position.z) * 0.5 + 0.5;
}
