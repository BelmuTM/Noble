/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

vec3 windDir = frameTimeCounter * vec3(-0.2, 0.35, -1.0);

void wavingLeaves(inout vec3 worldPosition, float skyFalloff) {
    worldPosition += (sin(worldPosition * vec3(1.0, 1.4, 1.05) + windDir * vec3(2.0, 3.2, 2.3)) * vec3(0.1, 0.06, 0.2)) * 0.15 * skyFalloff;
}

void wavingPlants(inout vec3 worldPosition, float skyFalloff, bool isTopVertex, bool isTopBlock) {
	vec2 offset  = (sin(worldPosition.xz * vec2(1.62, 1.82) + windDir.xz * vec2(2.0)) * vec2(0.1, 0.2)) * 0.35;
		 offset *= (isTopBlock ? 1.5 : float(isTopVertex)) * skyFalloff;

	worldPosition.xz += offset;
}

void animate(inout vec3 worldPosition, bool isTopVertex, float skyFalloff) {
	worldPosition += cameraPosition;
	
	switch(blockId) {
		case LEAVES_ID:              wavingLeaves(worldPosition, skyFalloff);                     break;
		case DOUBLE_PLANTS_LOWER_ID: wavingPlants(worldPosition, skyFalloff, isTopVertex, false); break;
		case DOUBLE_PLANTS_UPPER_ID: wavingPlants(worldPosition, skyFalloff, isTopVertex, true);  break;
		case PLANTS_ID:              wavingPlants(worldPosition, skyFalloff, isTopVertex, false); break;
	}
	worldPosition -= cameraPosition;
}
