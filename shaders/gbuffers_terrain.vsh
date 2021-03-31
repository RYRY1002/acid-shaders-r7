#version 120


//#define TEXTURE_FIX // If you're using 1.7.2, it has a texture glitch where certain sides of blocks are mirrored. Enable the following to compensate and keep lighting correct.

#define WorldSpace // Keeps it so that the Acid doesn't move around to where you are looking.

varying float materialIDs2;

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;
varying vec3 worldPosition;


attribute vec4 mc_Entity;

uniform int worldTime;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform float aspectRatio;

uniform sampler2D noisetex;

varying vec3 normal;
varying vec3 tangent;
varying vec3 binormal;
varying vec2 waves;
varying vec3 worldNormal;

varying float distance;
//varying float idCheck;

varying float materialIDs;

varying mat3 tbnMatrix;
varying vec4 vertexPos;
varying vec3 vertexViewVector;

varying vec4 shadowPosition;

const float sunPathRotation = -40.0;
const float PI = 3.1415926535;
const float rad = 0.01745329;

#define WAVING_GRASS
#define WAVING_WHEAT
#define WAVING_LEAVES
//#define WAVING_ALL // Makes all blocks wave around.


#define ANIMATION_SPEED 1.0 // [0.0 0.1 0.125 0.15 0.175 0.2 0.225 0.25 0.275 0.3 0.325 0.35 0.375 0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0 2.2 2.4 2.6 2.8 3.0 3.2 3.4 3.6 3.8 4.0 4.2 4.4 4.6 4.8 5.0 10.0 50.0 100.0]

//#define ANIMATE_USING_WORLDTIME // Animate blocks using the time of day instead of the amount of frames rendered



#ifdef ANIMATE_USING_WORLDTIME
#define FRAME_TIME worldTime * ANIMATION_SPEED / 20.0f
#else
#define FRAME_TIME frameTimeCounter * ANIMATION_SPEED
#endif

vec4 cubic(float x)
{
    float x2 = x * x;
    float x3 = x2 * x;
    vec4 w;
    w.x =   -x3 + 3*x2 - 3*x + 1;
    w.y =  3*x3 - 6*x2       + 4;
    w.z = -3*x3 + 3*x2 + 3*x + 1;
    w.w =  x3;
    return w / 6.f;
}

vec4 BicubicTexture(in sampler2D tex, in vec2 coord)
{
	int resolution = 64;

	coord *= resolution;

	float fx = fract(coord.x);
    float fy = fract(coord.y);
    coord.x -= fx;
    coord.y -= fy;

    vec4 xcubic = cubic(fx);
    vec4 ycubic = cubic(fy);

    vec4 c = vec4(coord.x - 0.5, coord.x + 1.5, coord.y - 0.5, coord.y + 1.5);
    vec4 s = vec4(xcubic.x + xcubic.y, xcubic.z + xcubic.w, ycubic.x + ycubic.y, ycubic.z + ycubic.w);
    vec4 offset = c + vec4(xcubic.y, xcubic.w, ycubic.y, ycubic.w) / s;

    vec4 sample0 = texture2D(tex, vec2(offset.x, offset.z) / resolution);
    vec4 sample1 = texture2D(tex, vec2(offset.y, offset.z) / resolution);
    vec4 sample2 = texture2D(tex, vec2(offset.x, offset.w) / resolution);
    vec4 sample3 = texture2D(tex, vec2(offset.y, offset.w) / resolution);

    float sx = s.x / (s.x + s.y);
    float sy = s.z / (s.z + s.w);

    return mix( mix(sample3, sample2, sx), mix(sample1, sample0, sx), sy);
}




// 	vec4 result = mix(texCenter, texRight, vec4(f.x));
// 	return result;
// }


vec4 TextureSmooth(in sampler2D tex, in vec2 coord)
{
	int level = 0;
	vec2 res = vec2(64.0f);
	coord = coord * res;
	vec2 i = floor(coord);
	vec2 f = fract(coord);
	f = f * f * (3.0f - 2.0f * f);
	//f = 1.0f - (cos(f * 3.1415f) * 0.5f + 0.5f);

	//i -= vec2(0.5f);

	vec2 icoordCenter 		= i / res;
	vec2 icoordRight 		= (i + vec2(1.0f, 0.0f)) / res;
	vec2 icoordUp	 		= (i + vec2(0.0f, 1.0f)) / res;
	vec2 icoordUpRight	 	= (i + vec2(1.0f, 1.0f)) / res;


	vec4 texCenter 	= texture2DLod(tex, icoordCenter, 	level);
	vec4 texRight 	= texture2DLod(tex, icoordRight, 	level);
	vec4 texUp 		= texture2DLod(tex, icoordUp, 		level);
	vec4 texUpRight	= texture2DLod(tex, icoordUpRight,  level);

	texCenter = mix(texCenter, texUp, vec4(f.y));
	texRight  = mix(texRight, texUpRight, vec4(f.y));

	vec4 result = mix(texCenter, texRight, vec4(f.x));
	return result;
}

float Impulse(in float x, in float k)
{
	float h = k*x;
    return pow(h*exp(1.0f-h), 5.0f);
}

float RepeatingImpulse(in float x, in float scale)
{
	float time = x;
		  time = mod(time, scale);

	return Impulse(time, 3.0f / scale);
}

void rotateRad(inout vec2 vector, float degrees) {
	degrees *= rad;

	vector *= mat2(cos(degrees), -sin(degrees),
				   sin(degrees),  cos(degrees));
}

void rotate(inout vec2 vector, float radians) {
	vector *= mat2(cos(radians), -sin(radians),
				   sin(radians),  cos(radians));
}

vec4 locposition = gl_ModelViewMatrix * gl_Vertex;

#include "include/acidR6.glsl"

void main() {

	color = gl_Color;

	texcoord = gl_MultiTexCoord0;

	lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;

	vec4 viewpos = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	vec4 position = viewpos;

	worldPosition = viewpos.xyz + cameraPosition.xyz;

	float waveCoeff = 0.0f;


	//Entity checker
	// if (mc_Entity.x == 1920.0f)
	// {
	// 	texcoord.st = vec2(0.2f);
	// }

	//Gather materials
	materialIDs = 1.0f;

	//Grass
	if  (  mc_Entity.x == 31.0

		|| mc_Entity.x == 38.0f 	//Rose
		|| mc_Entity.x == 37.0f 	//Flower
		|| mc_Entity.x == 1925.0f 	//Biomes O Plenty: Medium Grass
		|| mc_Entity.x == 1920.0f 	//Biomes O Plenty: Thorns, barley
		|| mc_Entity.x == 1921.0f 	//Biomes O Plenty: Sunflower

		)
	{
		materialIDs = max(materialIDs, 2.0f);
		waveCoeff = 1.0f;
	}

	if (  mc_Entity.x == 175.0f)
	{
		materialIDs = max(materialIDs, 2.0f);
	}

	//Wheat
	if (mc_Entity.x == 59.0) {
		materialIDs = max(materialIDs, 2.0f);
		waveCoeff = 1.0f;
	}

	//Leaves
	if   ( mc_Entity.x == 18.0

		|| mc_Entity.x == 1962.0f //Biomes O Plenty: Leaves
		|| mc_Entity.x == 1924.0f //Biomes O Plenty: Leaves
		|| mc_Entity.x == 1923.0f //Biomes O Plenty: Leaves
		|| mc_Entity.x == 1926.0f //Biomes O Plenty: Leaves
		|| mc_Entity.x == 1936.0f //Biomes O Plenty: Giant Flower Leaves
		|| mc_Entity.x == 161.0f //Biomes O Plenty: Giant Flower Leaves

		 ) {
		materialIDs = max(materialIDs, 3.0f);
	}


	//Gold block
	if (mc_Entity.x == 41) {
		materialIDs = max(materialIDs, 20.0f);
	}

	//Iron block
	if (mc_Entity.x == 42) {
		materialIDs = max(materialIDs, 21.0f);
	}

	//Diamond Block
	if (mc_Entity.x == 57) {
		materialIDs = max(materialIDs, 22.0f);
	}

	//Emerald Block
	if (mc_Entity.x == -123) {
		materialIDs = max(materialIDs, 23.0f);
	}



	//sand
	if (mc_Entity.x == 12) {
		materialIDs = max(materialIDs, 24.0f);
	}

	//sandstone
	if (mc_Entity.x == 24 || mc_Entity.x == -128) {
		materialIDs = max(materialIDs, 25.0f);
	}

	//stone
	if (mc_Entity.x == 1) {
		materialIDs = max(materialIDs, 26.0f);
	}

	//cobblestone
	if (mc_Entity.x == 4) {
		materialIDs = max(materialIDs, 27.0f);
	}

	//wool
	if (mc_Entity.x == 35) {
		materialIDs = max(materialIDs, 28.0f);
	}


	//torch
	if (mc_Entity.x == 50) {
		materialIDs = max(materialIDs, 30.0f);
	}

	//lava
	if (mc_Entity.x == 10 || mc_Entity.x == 11) {
		materialIDs = max(materialIDs, 31.0f);
	}

	//glowstone and lamp
	if (mc_Entity.x == 89 || mc_Entity.x == 124) {
		materialIDs = max(materialIDs, 32.0f);
	}

	//fire
	if (mc_Entity.x == 51) {
		materialIDs = max(materialIDs, 33.0f);
	}

  materialIDs2 = mc_Entity.x;



	float tick = FRAME_TIME;


float grassWeight = mod(texcoord.t * 16.0f, 1.0f / 16.0f);

float lightWeight = clamp((lmcoord.t * 33.05f / 32.0f) - 1.05f / 32.0f, 0.0f, 1.0f);
	  lightWeight *= 1.1f;
	  lightWeight -= 0.1f;
	  lightWeight = max(0.0f, lightWeight);
	  lightWeight = pow(lightWeight, 5.0f);

	  // if (texcoord.t < 0.65f) {
	  // 	grassWeight = 1.0f;
	  // } else {
	  // 	grassWeight = 0.0f;
	  // }

	  if (grassWeight < 0.01f) {
	  	grassWeight = 1.0f;
	  } else {
	  	grassWeight = 0.0f;
	  }

#ifdef WAVING_GRASS
//Waving All
	if (waveCoeff > 0.5f) {
    vec2 angleLight = vec2(0.0f);
    vec2 angleHeavy = vec2(0.0f);
    vec2 angle 		= vec2(0.0f);

    vec3 pn0 = position.xyz;
      pn0.x -= FRAME_TIME / 3.0f;

    vec3 stoch = BicubicTexture(noisetex, pn0.xz / 64.0f).xyz;
    vec3 stochLarge = BicubicTexture(noisetex, position.xz / (64.0f * 6.0f)).xyz;

    vec3 pn = position.xyz;
      pn.x *= 2.0f;
      pn.x -= FRAME_TIME * 15.0f;
      pn.z *= 8.0f;

    vec3 stochLargeMoving = BicubicTexture(noisetex, pn.xz / (64.0f * 10.0f)).xyz;



    vec3 p = position.xyz;
      p.x += sin(p.z / 2.0f) * 1.0f;
      p.xz += stochLarge.rg * 5.0f;

    float windStrength = mix(0.85f, 1.0f, rainStrength);
    float windStrengthRandom = stochLargeMoving.x;
        windStrengthRandom = pow(windStrengthRandom, mix(2.0f, 1.0f, rainStrength));
        //windStrength *= mix(windStrengthRandom, 0.5f, rainStrength * 0.25f);
        windStrength = 0.05f;

    //heavy wind
    float heavyAxialFrequency 			= 8.0f;
    float heavyAxialWaveLocalization 	= 0.9f;
    float heavyAxialRandomization 		= 13.0f;
    float heavyAxialAmplitude 			= 15.0f;
    float heavyAxialOffset 				= 15.0f;

    float heavyLateralFrequency 		= 6.732f;
    float heavyLateralWaveLocalization 	= 1.274f;
    float heavyLateralRandomization 	= 1.0f;
    float heavyLateralAmplitude 		= 6.0f;
    float heavyLateralOffset 			= 0.0f;

    //light wind
    float lightAxialFrequency 			= 5.5f;
    float lightAxialWaveLocalization 	= 1.1f;
    float lightAxialRandomization 		= 21.0f;
    float lightAxialAmplitude 			= 5.0f;
    float lightAxialOffset 				= 5.0f;

    float lightLateralFrequency 		= 5.9732f;
    float lightLateralWaveLocalization 	= 1.174f;
    float lightLateralRandomization 	= 0.0f;
    float lightLateralAmplitude 		= 1.0f;
    float lightLateralOffset 			= 0.0f;

    float windStrengthCrossfade = clamp(windStrength * 2.0f - 1.0f, 0.0f, 1.0f);
    float lightWindFade = clamp(windStrength * 2.0f, 0.2f, 1.0f);

    angleLight.x += sin(FRAME_TIME * lightAxialFrequency 		- p.x * lightAxialWaveLocalization		+ stoch.x * lightAxialRandomization) 	* lightAxialAmplitude 		+ lightAxialOffset;
    angleLight.y += sin(FRAME_TIME * lightLateralFrequency 	- p.x * lightLateralWaveLocalization 	+ stoch.x * lightLateralRandomization) 	* lightLateralAmplitude  	+ lightLateralOffset;

    angleHeavy.x += sin(FRAME_TIME * heavyAxialFrequency 		- p.x * heavyAxialWaveLocalization		+ stoch.x * heavyAxialRandomization) 	* heavyAxialAmplitude 		+ heavyAxialOffset;
    angleHeavy.y += sin(FRAME_TIME * heavyLateralFrequency 	- p.x * heavyLateralWaveLocalization 	+ stoch.x * heavyLateralRandomization) 	* heavyLateralAmplitude  	+ heavyLateralOffset;

    angle = mix(angleLight * lightWindFade, angleHeavy, vec2(windStrengthCrossfade));
    angle *= 2.0f;

    // //Rotate block pivoting from bottom based on angle
    position.x += (sin((angle.x / 180.0f) * 3.141579f)) * grassWeight * lightWeight						* 1.0f	;
    position.z += (sin((angle.y / 180.0f) * 3.141579f)) * grassWeight * lightWeight						* 1.0f	;
    position.y += (cos(((angle.x + angle.y) / 180.0f) * 3.141579f) - 1.0f)  * grassWeight * lightWeight	* 1.0f	;
  }

#endif

#ifdef WAVING_WHEAT
//Wheat
  if (mc_Entity.x == 59.0 && texcoord.t < 0.35) {
    vec2 angleLight = vec2(0.0f);
    vec2 angleHeavy = vec2(0.0f);
    vec2 angle 		= vec2(0.0f);

    vec3 pn0 = position.xyz;
      pn0.x -= FRAME_TIME / 3.0f;

    vec3 stoch = BicubicTexture(noisetex, pn0.xz / 64.0f).xyz;
    vec3 stochLarge = BicubicTexture(noisetex, position.xz / (64.0f * 6.0f)).xyz;

    vec3 pn = position.xyz;
      pn.x *= 2.0f;
      pn.x -= FRAME_TIME * 15.0f;
      pn.z *= 8.0f;

    vec3 stochLargeMoving = BicubicTexture(noisetex, pn.xz / (64.0f * 10.0f)).xyz;



    vec3 p = position.xyz;
      p.x += sin(p.z / 2.0f) * 1.0f;
      p.xz += stochLarge.rg * 5.0f;

    float windStrength = mix(0.85f, 1.0f, rainStrength);
    float windStrengthRandom = stochLargeMoving.x;
        windStrengthRandom = pow(windStrengthRandom, mix(2.0f, 1.0f, rainStrength));
        //windStrength *= mix(windStrengthRandom, 0.5f, rainStrength * 0.25f);
        windStrength = 0.05f;

    //heavy wind
    float heavyAxialFrequency 			= 8.0f;
    float heavyAxialWaveLocalization 	= 0.9f;
    float heavyAxialRandomization 		= 13.0f;
    float heavyAxialAmplitude 			= 15.0f;
    float heavyAxialOffset 				= 15.0f;

    float heavyLateralFrequency 		= 6.732f;
    float heavyLateralWaveLocalization 	= 1.274f;
    float heavyLateralRandomization 	= 1.0f;
    float heavyLateralAmplitude 		= 6.0f;
    float heavyLateralOffset 			= 0.0f;

    //light wind
    float lightAxialFrequency 			= 5.5f;
    float lightAxialWaveLocalization 	= 1.1f;
    float lightAxialRandomization 		= 21.0f;
    float lightAxialAmplitude 			= 5.0f;
    float lightAxialOffset 				= 5.0f;

    float lightLateralFrequency 		= 5.9732f;
    float lightLateralWaveLocalization 	= 1.174f;
    float lightLateralRandomization 	= 0.0f;
    float lightLateralAmplitude 		= 1.0f;
    float lightLateralOffset 			= 0.0f;

    float windStrengthCrossfade = clamp(windStrength * 2.0f - 1.0f, 0.0f, 1.0f);
    float lightWindFade = clamp(windStrength * 2.0f, 0.2f, 1.0f);

    angleLight.x += sin(FRAME_TIME * lightAxialFrequency 		- p.x * lightAxialWaveLocalization		+ stoch.x * lightAxialRandomization) 	* lightAxialAmplitude 		+ lightAxialOffset;
    angleLight.y += sin(FRAME_TIME * lightLateralFrequency 	- p.x * lightLateralWaveLocalization 	+ stoch.x * lightLateralRandomization) 	* lightLateralAmplitude  	+ lightLateralOffset;

    angleHeavy.x += sin(FRAME_TIME * heavyAxialFrequency 		- p.x * heavyAxialWaveLocalization		+ stoch.x * heavyAxialRandomization) 	* heavyAxialAmplitude 		+ heavyAxialOffset;
    angleHeavy.y += sin(FRAME_TIME * heavyLateralFrequency 	- p.x * heavyLateralWaveLocalization 	+ stoch.x * heavyLateralRandomization) 	* heavyLateralAmplitude  	+ heavyLateralOffset;

    angle = mix(angleLight * lightWindFade, angleHeavy, vec2(windStrengthCrossfade));
    angle *= 2.0f;

    // //Rotate block pivoting from bottom based on angle
    position.x += (sin((angle.x / 180.0f) * 3.141579f)) * grassWeight * lightWeight						* 1.0f	;
    position.z += (sin((angle.y / 180.0f) * 3.141579f)) * grassWeight * lightWeight						* 1.0f	;
    position.y += (cos(((angle.x + angle.y) / 180.0f) * 3.141579f) - 1.0f)  * grassWeight * lightWeight	* 1.0f	;
  }

#endif

#ifdef WAVING_LEAVES
//Waving Leaves
	if (materialIDs == 3.0f && texcoord.t < 1.90 && texcoord.t > -1.0) {
    vec2 angleLight = vec2(0.0f);
    vec2 angleHeavy = vec2(0.0f);
    vec2 angle 		= vec2(0.0f);

    vec3 pn0 = position.xyz;
      pn0.x -= FRAME_TIME / 3.0f;

    vec3 stoch = BicubicTexture(noisetex, pn0.xz / 64.0f).xyz;
    vec3 stochLarge = BicubicTexture(noisetex, position.xz / (64.0f * 6.0f)).xyz;

    vec3 pn = position.xyz;
      pn.x *= 2.0f;
      pn.x -= FRAME_TIME * 15.0f;
      pn.z *= 8.0f;

    vec3 stochLargeMoving = BicubicTexture(noisetex, pn.xz / (64.0f * 10.0f)).xyz;



    vec3 p = position.xyz;
      p.x += sin(p.z / 2.0f) * 1.0f;
      p.xz += stochLarge.rg * 5.0f;

    float windStrength = mix(0.85f, 1.0f, rainStrength);
    float windStrengthRandom = stochLargeMoving.x;
        windStrengthRandom = pow(windStrengthRandom, mix(2.0f, 1.0f, rainStrength));
        //windStrength *= mix(windStrengthRandom, 0.5f, rainStrength * 0.25f);
        windStrength = 0.05f;

    //heavy wind
    float heavyAxialFrequency 			= 8.0f;
    float heavyAxialWaveLocalization 	= 0.9f;
    float heavyAxialRandomization 		= 13.0f;
    float heavyAxialAmplitude 			= 15.0f;
    float heavyAxialOffset 				= 15.0f;

    float heavyLateralFrequency 		= 6.732f;
    float heavyLateralWaveLocalization 	= 1.274f;
    float heavyLateralRandomization 	= 1.0f;
    float heavyLateralAmplitude 		= 6.0f;
    float heavyLateralOffset 			= 0.0f;

    //light wind
    float lightAxialFrequency 			= 5.5f;
    float lightAxialWaveLocalization 	= 1.1f;
    float lightAxialRandomization 		= 21.0f;
    float lightAxialAmplitude 			= 5.0f;
    float lightAxialOffset 				= 5.0f;

    float lightLateralFrequency 		= 5.9732f;
    float lightLateralWaveLocalization 	= 1.174f;
    float lightLateralRandomization 	= 0.0f;
    float lightLateralAmplitude 		= 1.0f;
    float lightLateralOffset 			= 0.0f;

    float windStrengthCrossfade = clamp(windStrength * 2.0f - 1.0f, 0.0f, 1.0f);
    float lightWindFade = clamp(windStrength * 2.0f, 0.2f, 1.0f);

    angleLight.x += sin(FRAME_TIME * lightAxialFrequency 		- p.x * lightAxialWaveLocalization		+ stoch.x * lightAxialRandomization) 	* lightAxialAmplitude 		+ lightAxialOffset;
    angleLight.y += sin(FRAME_TIME * lightLateralFrequency 	- p.x * lightLateralWaveLocalization 	+ stoch.x * lightLateralRandomization) 	* lightLateralAmplitude  	+ lightLateralOffset;

    angleHeavy.x += sin(FRAME_TIME * heavyAxialFrequency 		- p.x * heavyAxialWaveLocalization		+ stoch.x * heavyAxialRandomization) 	* heavyAxialAmplitude 		+ heavyAxialOffset;
    angleHeavy.y += sin(FRAME_TIME * heavyLateralFrequency 	- p.x * heavyLateralWaveLocalization 	+ stoch.x * heavyLateralRandomization) 	* heavyLateralAmplitude  	+ heavyLateralOffset;

    angle = mix(angleLight * lightWindFade, angleHeavy, vec2(windStrengthCrossfade));
    angle *= 2.0f;

    // //Rotate block pivoting from bottom based on angle
    position.x += (sin((angle.x / 180.0f) * 3.141579f)) * grassWeight * lightWeight						* 1.0f	;
    position.z += (sin((angle.y / 180.0f) * 3.141579f)) * grassWeight * lightWeight						* 1.0f	;
    position.y += (cos(((angle.x + angle.y) / 180.0f) * 3.141579f) - 1.0f)  * grassWeight * lightWeight	* 1.0f	;
  }

#endif

#ifdef WAVING_ALL
	//Waving All
		vec2 angleLight = vec2(0.0f);
		vec2 angleHeavy = vec2(0.0f);
		vec2 angle 		= vec2(0.0f);

		vec3 pn0 = position.xyz;
			 pn0.x -= FRAME_TIME / 3.0f;

		vec3 stoch = BicubicTexture(noisetex, pn0.xz / 64.0f).xyz;
		vec3 stochLarge = BicubicTexture(noisetex, position.xz / (64.0f * 6.0f)).xyz;

		vec3 pn = position.xyz;
			 pn.x *= 2.0f;
			 pn.x -= FRAME_TIME * 15.0f;
			 pn.z *= 8.0f;

		vec3 stochLargeMoving = BicubicTexture(noisetex, pn.xz / (64.0f * 10.0f)).xyz;



		vec3 p = position.xyz;
		 	 p.x += sin(p.z / 2.0f) * 1.0f;
		 	 p.xz += stochLarge.rg * 5.0f;

		float windStrength = mix(0.85f, 1.0f, rainStrength);
		float windStrengthRandom = stochLargeMoving.x;
			  windStrengthRandom = pow(windStrengthRandom, mix(2.0f, 1.0f, rainStrength));
			  windStrength *= mix(windStrengthRandom, 0.5f, rainStrength * 0.25f);
			  //windStrength = 1.0f;

		//heavy wind
		float heavyAxialFrequency 			= 8.0f;
		float heavyAxialWaveLocalization 	= 0.9f;
		float heavyAxialRandomization 		= 13.0f;
		float heavyAxialAmplitude 			= 15.0f;
		float heavyAxialOffset 				= 15.0f;

		float heavyLateralFrequency 		= 6.732f;
		float heavyLateralWaveLocalization 	= 1.274f;
		float heavyLateralRandomization 	= 1.0f;
		float heavyLateralAmplitude 		= 6.0f;
		float heavyLateralOffset 			= 0.0f;

		//light wind
		float lightAxialFrequency 			= 5.5f;
		float lightAxialWaveLocalization 	= 1.1f;
		float lightAxialRandomization 		= 21.0f;
		float lightAxialAmplitude 			= 5.0f;
		float lightAxialOffset 				= 5.0f;

		float lightLateralFrequency 		= 5.9732f;
		float lightLateralWaveLocalization 	= 1.174f;
		float lightLateralRandomization 	= 0.0f;
		float lightLateralAmplitude 		= 1.0f;
		float lightLateralOffset 			= 0.0f;

		float windStrengthCrossfade = clamp(windStrength * 2.0f - 1.0f, 0.0f, 1.0f);
		float lightWindFade = clamp(windStrength * 2.0f, 0.2f, 1.0f);

		angleLight.x += sin(FRAME_TIME * lightAxialFrequency 		- p.x * lightAxialWaveLocalization		+ stoch.x * lightAxialRandomization) 	* lightAxialAmplitude 		+ lightAxialOffset;
		angleLight.y += sin(FRAME_TIME * lightLateralFrequency 	- p.x * lightLateralWaveLocalization 	+ stoch.x * lightLateralRandomization) 	* lightLateralAmplitude  	+ lightLateralOffset;

		angleHeavy.x += sin(FRAME_TIME * heavyAxialFrequency 		- p.x * heavyAxialWaveLocalization		+ stoch.x * heavyAxialRandomization) 	* heavyAxialAmplitude 		+ heavyAxialOffset;
		angleHeavy.y += sin(FRAME_TIME * heavyLateralFrequency 	- p.x * heavyLateralWaveLocalization 	+ stoch.x * heavyLateralRandomization) 	* heavyLateralAmplitude  	+ heavyLateralOffset;

		angle = mix(angleLight * lightWindFade, angleHeavy, vec2(windStrengthCrossfade));
		angle *= 2.0f;

		// //Rotate block pivoting from bottom based on angle
		position.x += (sin((angle.x / 180.0f) * 3.141579f)) * grassWeight * lightWeight						* 1.0f	;
		position.z += (sin((angle.y / 180.0f) * 3.141579f)) * grassWeight * lightWeight						* 1.0f	;
		position.y += (cos(((angle.x + angle.y) / 180.0f) * 3.141579f) - 1.0f)  * grassWeight * lightWeight	* 1.0f	;

#endif

  position.xyz += cameraPosition.xyz;


	distance = sqrt(locposition.x * locposition.x + locposition.y * locposition.y + locposition.z * locposition.z);

	position.xyz -= cameraPosition.xyz;

  shadowPosition = position;

  #include "include/acidenable.glsl"

  #ifdef WorldSpace
	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;
	#endif
	#ifndef WorldSpace
	gl_Position = gl_ProjectionMatrix * gbufferModelViewInverse * position;
	#endif






	// float colorDiff = abs(color.r - color.g);
	// 	  colorDiff += abs(color.r - color.b);
	// 	  colorDiff += abs(color.g - color.b);

	// if (colorDiff < 0.001f && mc_Entity.x != -1.0f && mc_Entity.x != 63 && mc_Entity.x != 68 && mc_Entity.x != 323) {

	// 	float lum = color.r + color.g + color.b;
	// 		  lum /= 3.0f;

	// 	if (lum < 0.92f) {
	// 		color.rgb = vec3(1.0f);
	// 	}

	// }

	gl_FogFragCoord = gl_Position.z;


	normal = normalize(gl_NormalMatrix * gl_Normal);
	worldNormal = gl_Normal;

	float texFix = -1.0f;

	#ifdef TEXTURE_FIX
	texFix = 1.0f;
	#endif

	//if(distance < 80.0f){
		if (gl_Normal.x > 0.5) {
			//  1.0,  0.0,  0.0
			tangent  = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  texFix));
			binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
			if (abs(materialIDs - 32.0f) < 0.1f)								//Optifine glowstone fix
				color *= 1.75f;
		} else if (gl_Normal.x < -0.5) {
			// -1.0,  0.0,  0.0
			tangent  = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
			binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
			if (abs(materialIDs - 32.0f) < 0.1f)								//Optifine glowstone fix
				color *= 1.75f;
		} else if (gl_Normal.y > 0.5) {
			//  0.0,  1.0,  0.0
			tangent  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
			binormal = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
		} else if (gl_Normal.y < -0.5) {
			//  0.0, -1.0,  0.0
			tangent  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
			binormal = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
		} else if (gl_Normal.z > 0.5) {
			//  0.0,  0.0,  1.0
			tangent  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
			binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
		} else if (gl_Normal.z < -0.5) {
			//  0.0,  0.0, -1.0
			tangent  = normalize(gl_NormalMatrix * vec3( texFix,  0.0,  0.0));
			binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
		}
	//}


	tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
                     tangent.y, binormal.y, normal.y,
                     tangent.z, binormal.z, normal.z);

	vertexPos = gl_Vertex;
}
