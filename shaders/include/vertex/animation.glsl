/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

const float windSpeed = 5.3;
float wavingSpeed     = frameTimeCounter * windSpeed;
vec3 windDir          = wavingSpeed * vec3(0.8, 0.6, -0.9);

void wavingLeaves(inout vec3 worldPos) {
    worldPos += sin(worldPos * vec3(0.5, 0.1, 0.4) + windDir * vec3(0.3, 0.2, 0.5)) * 0.1;
}

void animate(inout vec3 worldPos) {
	switch(blockId) {
		case 8: wavingLeaves(worldPos); break;
	}
}
