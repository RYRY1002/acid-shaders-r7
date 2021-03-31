#version 120

/*
 _______ _________ _______  _______  _
(  ____ \\__   __/(  ___  )(  ____ )( )
| (    \/   ) (   | (   ) || (    )|| |
| (_____    | |   | |   | || (____)|| |
(_____  )   | |   | |   | ||  _____)| |
      ) |   | |   | |   | || (      (_)
/\____) |   | |   | (___) || )       _
\_______)   )_(   (_______)|/       (_)

Do not modify this code until you have read the LICENSE.txt contained in the root directory of this shaderpack!

*/

#define BANDING_FIX_FACTOR 1.0f
//#define SMOOTH_SKY // Makes the sky smoother. (Doesn't have any visible effect as far as I can tell)
#define GODRAYS // Makes the sun cast rays that will visibly stop when hitting another object. If you disable this, you MUST enable "No Godrays" so the shader doesn't crash.
	const float exposure = 0.0025;			//godrays intensity 0.0009 is default
	const float grdensity = 1.0;
	const int NUM_SAMPLES = 10;			//increase this for better quality at the cost of performance /8 is default
	const float Moon_exposure = 0.003;			//Moonrays intensity 0.0009 is default, increase to make brighter

#define MOONRAYS					// Enables Godrays at night. Note: Moonrays have a bug at sunset/sunrise


#define NO_UNDERWATER_RAYS // Disable this to disable underwater Godrays.

//#define NO_GODRAYS				// If you disable Godrays then you MUST enable this so the shader won't crash.
/* DRAWBUFFERS:2 */
const bool gcolorMipmapEnabled = false;
const bool compositeMipmapEnabled = false;

uniform sampler2D gcolor;
uniform sampler2D gdepth;
uniform sampler2D gdepthtex;
uniform sampler2D gnormal;
uniform sampler2D composite;
uniform sampler2D noisetex;
//uniform sampler2D gaux1;

uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform float wetness;
uniform float aspectRatio;
uniform float frameTimeCounter;
uniform int worldTime;
uniform int   isEyeInWater;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 shadowModelViewInverse;
uniform vec3 sunPosition;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform vec3 fogColor;

uniform mat4 gbufferModelView;

varying vec4 texcoord;

varying vec3 lightVector;
varying vec3 upVector;

varying float timeSunriseSunset;
varying float timeNoon;
varying float timeMidnight;
varying float timeSkyDark;

varying vec3 colorSunlight;
varying vec3 colorSkylight;
varying vec3 colorBouncedSunlight;




#define ANIMATION_SPEED 1.0 // [0.0 0.1 0.125 0.15 0.175 0.2 0.225 0.25 0.275 0.3 0.325 0.35 0.375 0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0 2.2 2.4 2.6 2.8 3.0 3.2 3.4 3.6 3.8 4.0 4.2 4.4 4.6 4.8 5.0 10.0 50.0 100.0]

//#define ANIMATE_USING_WORLDTIME // Animate blocks using the time of day instead of the amount of frames rendered



#ifdef ANIMATE_USING_WORLDTIME
#define FRAME_TIME worldTime * ANIMATION_SPEED / 20.0f * 0.0
#else
#define FRAME_TIME frameTimeCounter * ANIMATION_SPEED * 0.0
#endif


/////////////////////////FUNCTIONS/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////FUNCTIONS/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//Get gbuffer textures
vec3  	GetAlbedoLinear(in vec2 coord) {			//Function that retrieves the diffuse texture and convert it into linear space.
	return pow(texture2D(gcolor, coord).rgb, vec3(2.2f));
}

vec3 GetNormals(in vec2 coord) {
	vec3 normal = vec3(0.0f);
		 normal = texture2DLod(gnormal, coord.st, 0).rgb;
	normal = normal * 2.0f - 1.0f;

	normal = normalize(normal);

	return normal;
}

float GetDepth(in vec2 coord) {
	return texture2D(gdepthtex, coord).x;
}

float 	ExpToLinearDepth(in float depth)
{
	return 2.0f * near * far / (far + near - (2.0f * depth - 1.0f) * (far - near));
}

float GetDepthLinear(vec2 coord) {
    return 2.0 * near * far / (far + near - (2.0 * texture2D(gdepthtex, coord).x - 1.0) * (far - near));
}

vec4  	GetViewSpacePosition(in vec2 coord) {	//Function that calculates the screen-space position of the objects in the scene using the depth texture and the texture coordinates of the full-screen quad
	float depth = GetDepth(coord);
		  //depth += float(GetMaterialMask(coord, 5)) * 0.38f;
	vec4 fragposition = gbufferProjectionInverse * vec4(coord.s * 2.0f - 1.0f, coord.t * 2.0f - 1.0f, 2.0f * depth - 1.0f, 1.0f);
		 fragposition /= fragposition.w;

	return fragposition;
}

float 	GetMaterialIDs(in vec2 coord) {			//Function that retrieves the texture that has all material IDs stored in it
	return texture2D(gdepth, coord).r;
}

float GetSunlightVisibility(in vec2 coord)
{
	return texture2D(gdepth, coord).g;
}

float cubicPulse(float c, float w, float x)
{
	x = abs(x - c);
	if (x > w) return 0.0f;
	x /= w;
	return 1.0f - x * x * (3.0f - 2.0f * x);
}

bool 	GetMaterialMask(in vec2 coord, in int ID, in float matID) {
		  matID = floor(matID * 255.0f);

	if (matID == ID) {
		return true;
	} else {
		return false;
	}
}

bool 	GetSkyMask(in vec2 coord, in float matID)
{
	matID = floor(matID * 255.0f);

	if (matID < 1.0f || matID > 254.0f)
	{
		return true;
	} else {
		return false;
	}
}

bool 	GetSkyMask(in vec2 coord)
{
	float matID = GetMaterialIDs(coord);
	matID = floor(matID * 255.0f);

	if (matID < 1.0f || matID > 254.0f)
	{
		return true;
	} else {
		return false;
	}
}

float 	GetSpecularity(in vec2 coord)
{
	return texture2D(composite, coord).r;
}

float 	GetRoughness(in vec2 coord)
{
	return texture2D(composite, coord).b;
}

//Water
float 	GetWaterTex(in vec2 coord) {				//Function that returns the texture used for water. 0 means "this pixel is not water". 0.5 and greater means "this pixel is water".
	return texture2D(gnormal, coord).b;		//values from 0.5 to 1.0 represent the amount of sky light hitting the surface of the water. It is used to simulate fake sky reflections in composite1.fsh
}

bool  	GetWaterMask(in float matID) {					//Function that returns "true" if a pixel is water, and "false" if a pixel is not water.
	matID = floor(matID * 255.0f);

	if (matID >= 35.0f && matID <= 51) {
		return true;
	} else {
		return false;
	}
}

bool  	GetWaterMask(in vec2 coord) {					//Function that returns "true" if a pixel is water, and "false" if a pixel is not water.
	float matID = floor(GetMaterialIDs(coord) * 255.0f);

	if (matID >= 35.0f && matID <= 51) {
		return true;
	} else {
		return false;
	}
}

float 	GetLightmapSky(in vec2 coord) {
	return texture2D(gdepth, texcoord.st).b;
}

vec3 convertScreenSpaceToWorldSpace(vec2 co) {
    vec4 fragposition = gbufferProjectionInverse * vec4(vec3(co, texture2DLod(gdepthtex, co, 0).x) * 2.0 - 1.0, 1.0);
    fragposition /= fragposition.w;
    return fragposition.xyz;
}

vec3 convertCameraSpaceToScreenSpace(vec3 cameraSpace) {
    vec4 clipSpace = gbufferProjection * vec4(cameraSpace, 1.0);
    vec3 NDCSpace = clipSpace.xyz / clipSpace.w;
    vec3 screenSpace = 0.5 * NDCSpace + 0.5;
		 screenSpace.z = 0.1f;
    return screenSpace;
}

float  	CalculateDitherPattern1() {
	int[16] ditherPattern = int[16] (0 , 9 , 3 , 11,
								 	 13, 5 , 15, 7 ,
								 	 4 , 12, 2,  10,
								 	 16, 8 , 14, 6 );

	vec2 count = vec2(0.0f);
	     count.x = floor(mod(texcoord.s * viewWidth, 4.0f));
		 count.y = floor(mod(texcoord.t * viewHeight, 4.0f));

	int dither = ditherPattern[int(count.x) + int(count.y) * 4];

	return float(dither) / 17.0f;
}

float  	CalculateDitherPattern2() {
	int[16] ditherPattern = int[16] (4 , 12, 2,  10,
								 	 16, 8 , 14, 6 ,
								 	 0 , 9 , 3 , 11,
								 	 13, 5 , 15, 7 );

	vec2 count = vec2(0.0f);
	     count.x = floor(mod(texcoord.s * viewWidth, 4.0f));
		 count.y = floor(mod(texcoord.t * viewHeight, 4.0f));

	int dither = ditherPattern[int(count.x) + int(count.y) * 4];

	return float(dither) / 17.0f;
}

vec3 	CalculateNoisePattern1(vec2 offset, float size) {
	vec2 coord = texcoord.st;

	coord *= vec2(viewWidth, viewHeight);
	coord = mod(coord + offset, vec2(size));
	coord /= 64.0f;

	return texture2D(noisetex, coord).xyz;
}

float noise (in float offset)
{
	vec2 coord = texcoord.st + vec2(offset);
	float noise = clamp(fract(sin(dot(coord ,vec2(12.9898f,78.233f))) * 43758.5453f),0.0f,1.0f)*2.0f-1.0f;
	return noise;
}

float noise (in vec2 coord, in float offset)
{
	coord += vec2(offset);
	float noise = clamp(fract(sin(dot(coord ,vec2(12.9898f,78.233f))) * 43758.5453f),0.0f,1.0f)*2.0f-1.0f;
	return noise;
}

void 	DoNightEye(inout vec3 color) {			//Desaturates any color input at night, simulating the rods in the human eye

	float amount = 0.8f; 						//How much will the new desaturated and tinted image be mixed with the original image
	vec3 rodColor = vec3(0.2f, 0.5f, 1.0f); 	//Cyan color that humans percieve when viewing extremely low light levels via rod cells in the eye
	float colorDesat = dot(color, vec3(1.0f)); 	//Desaturated color

	color = mix(color, vec3(colorDesat) * rodColor, timeSkyDark * amount);
	//color.rgb = color.rgb;
}


float Get3DNoise(in vec3 pos)
{
	// pos.z += 0.0f;

	// pos.xyz += 0.5f;

	// vec3 p = floor(pos);
	// vec3 f = fract(pos);

	// f.x = f.x * f.x * (3.0f - 2.0f * f.x);
	// f.y = f.y * f.y * (3.0f - 2.0f * f.y);
	// f.z = f.z * f.z * (3.0f - 2.0f * f.z);

	// vec2 uv =  (p.xy + p.z * vec2(17.0f)) + f.xy;
	// vec2 uv2 = (p.xy + (p.z + 1.0f) * vec2(17.0f)) + f.xy;

	// // uv -= 0.5f;
	// // uv2 -= 0.5f;

	// vec2 coord =  (uv  + 0.5f) / 64.0f;
	// vec2 coord2 = (uv2 + 0.5f) / 64.0f;
	// float xy1 = texture2D(noisetex, coord).x;
	// float xy2 = texture2D(noisetex, coord2).x;
	// return mix(xy1, xy2, f.z);
	return texture2D(noisetex, pos.xz / 64.0f).x;
}

vec4 	GetCloudSpacePosition(in vec2 coord, in float depth, in float distanceMult)
{
	// depth *= 30.0f;

	float linDepth = depth;

	float expDepth = (far * (linDepth - near)) / (linDepth * (far - near));

	//Convert texture coordinates and depth into view space
	vec4 viewPos = gbufferProjectionInverse * vec4(coord.s * 2.0f - 1.0f, coord.t * 2.0f - 1.0f, 2.0f * expDepth - 1.0f, 1.0f);
		 viewPos /= viewPos.w;

	//Convert from view space to world space
	vec4 worldPos = gbufferModelViewInverse * viewPos;

	worldPos.xyz *= distanceMult;
	worldPos.xyz += cameraPosition.xyz;

	return worldPos;
}

/////////////////////////STRUCTS///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////STRUCTS///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

struct MaskStruct {

	float matIDs;

	bool sky;
	float sky2;
	bool land;
	bool tallGrass;
	bool leaves;
	bool ice;
	bool hand;
	bool translucent;
	bool glow;
	float sunspot;
	bool goldBlock;
	bool ironBlock;
	bool diamondBlock;
	bool emeraldBlock;
	bool sand;
	bool sandstone;
	bool stone;
	bool cobblestone;
	bool wool;

	bool torch;
	bool lava;
	bool glowstone;
	bool fire;

	bool water;

} mask;

struct Ray {
	vec3 dir;
	vec3 origin;
};

struct Plane {
	vec3 normal;
	vec3 origin;
};

struct SkyStruct { 				//All sky shading attributes
	vec3 	albedo;				//Diffuse texture aka "color texture" of the sky
	vec3 	tintColor; 			//Color that will be multiplied with the sky to tint it
	vec3 	sunglow;			//Color that will be added to the sky simulating scattered light arond the sun/moon
	vec3 	sunSpot; 			//Actual sun surface
} sky;

struct SkyStruct2 { 				//All sky shading attributes
	vec3 	albedo;				//Diffuse texture aka "color texture" of the sky
	vec3 	tintColor; 			//Color that will be multiplied with the sky to tint it
	vec3 	sunglow;			//Color that will be added to the sky simulating scattered light arond the sun/moon
	vec3 	sunSpot; 			//Actual sun surface
} sky2;

struct SurfaceStruct {
	SkyStruct 	    sky;			//Sky shading attributes and properties
	SkyStruct       sky2;     //Sky shading attributes and properties
	MaskStruct 		mask;			//Material ID Masks

	//Properties that are required for lighting calculation
		vec3 	color;					//Diffuse texture aka "color texture"
		vec3 	normal;					//Screen-space surface normals
		float 	depth;					//Scene depth
		float 	linearDepth;			//Scene depth

		vec4	screenSpacePosition;	//Vector representing the screen-space position of the surface

		float 	rDepth;
		float  	specularity;
		vec3 	specularColor;
		float 	roughness;
		float   fresnelPower;
		float 	baseSpecularity;
		Ray 	viewRay;


		vec4 	viewSpacePosition;
		vec4 	worldSpacePosition;
		vec3 	worldLightVector;
		vec3  	upVector;
		vec3 	lightVector;

		float 	sunlightVisibility;

		vec4 	reflection;

		float 	cloudAlpha;
} surface;

struct Intersection {
	vec3 pos;
	float distance;
	float angle;
};



/////////////////////////STRUCT FUNCTIONS//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////STRUCT FUNCTIONS//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

void 	CalculateMasks(inout MaskStruct mask) {
	mask.sky 			= GetSkyMask(texcoord.st, mask.matIDs);
	mask.land	 		= !mask.sky;
	mask.tallGrass 		= GetMaterialMask(texcoord.st, 2, mask.matIDs);
	mask.leaves	 		= GetMaterialMask(texcoord.st, 3, mask.matIDs);
	mask.ice		 	= GetMaterialMask(texcoord.st, 4, mask.matIDs);
	mask.hand	 		= GetMaterialMask(texcoord.st, 5, mask.matIDs);
	mask.translucent	= GetMaterialMask(texcoord.st, 6, mask.matIDs);

	mask.glow	 		= GetMaterialMask(texcoord.st, 10, mask.matIDs);

	mask.goldBlock 		= GetMaterialMask(texcoord.st, 20, mask.matIDs);
	mask.ironBlock 		= GetMaterialMask(texcoord.st, 21, mask.matIDs);
	mask.diamondBlock	= GetMaterialMask(texcoord.st, 22, mask.matIDs);
	mask.emeraldBlock	= GetMaterialMask(texcoord.st, 23, mask.matIDs);
	mask.sand	 		= GetMaterialMask(texcoord.st, 24, mask.matIDs);
	mask.sandstone 		= GetMaterialMask(texcoord.st, 25, mask.matIDs);
	mask.stone	 		= GetMaterialMask(texcoord.st, 26, mask.matIDs);
	mask.cobblestone	= GetMaterialMask(texcoord.st, 27, mask.matIDs);
	mask.wool			= GetMaterialMask(texcoord.st, 28, mask.matIDs);

	mask.torch 			= GetMaterialMask(texcoord.st, 30, mask.matIDs);
	mask.lava 			= GetMaterialMask(texcoord.st, 31, mask.matIDs);
	mask.glowstone 		= GetMaterialMask(texcoord.st, 32, mask.matIDs);
	mask.fire 			= GetMaterialMask(texcoord.st, 33, mask.matIDs);

	mask.water 			= GetWaterMask(mask.matIDs);
}

vec4 	ComputeRaytraceReflection(inout SurfaceStruct surface)
{
	float reflectionRange = 2.0f;
    float initialStepAmount = 1.0 - clamp(0.1f / 100.0, 0.0, 0.99);
		  initialStepAmount *= 1.0f;


	 // vec2 dither = CalculateNoisePattern1(vec2(0.0f), 4.0f).xy * 2.0f - 1.0f;
	 // vec3 ditherNormal = vec3(0.0f);
	 // 	 ditherNormal.x = dither.x;
	 // 	 ditherNormal.y = dither.y;
	 // 	 ditherNormal.z = sqrt(1.0f - dither.x * dither.x - dither.y * dither.y);
	 // 	 ditherNormal.z = -1.0f;

	 // 	 ditherNormal = normalize(ditherNormal);
	 // 	 ditherNormal -= normalize(surface.viewSpacePosition.xyz) * 1.0f;



    vec2 screenSpacePosition2D = texcoord.st;
    vec3 cameraSpacePosition = convertScreenSpaceToWorldSpace(screenSpacePosition2D);

    vec3 cameraSpaceNormal = surface.normal;
    	 //cameraSpaceNormal += ditherNormal * 0.65f * surface.roughness;

    vec3 cameraSpaceViewDir = normalize(cameraSpacePosition);
    vec3 cameraSpaceVector = initialStepAmount * normalize(reflect(cameraSpaceViewDir,cameraSpaceNormal));
    vec3 cameraSpaceVectorFar = far * normalize(reflect(cameraSpaceViewDir,cameraSpaceNormal));
	vec3 oldPosition = cameraSpacePosition;
    vec3 cameraSpaceVectorPosition = oldPosition + cameraSpaceVector;
    vec3 currentPosition = convertCameraSpaceToScreenSpace(cameraSpaceVectorPosition);
    vec4 color = vec4(pow(texture2D(gcolor, screenSpacePosition2D).rgb, vec3(3.0f + 1.2f)), 0.0);
    const int maxRefinements = 3;
	int numRefinements = 0;
    int count = 0;
	vec2 finalSamplePos = vec2(0.0f);

	int numSteps = 0;

    //while(count < far/initialStepAmount*reflectionRange)
    for (int i = 0; i < 40; i++)
    {
        if(currentPosition.x < 0 || currentPosition.x > 1 ||
           currentPosition.y < 0 || currentPosition.y > 1 ||
           currentPosition.z < 0 || currentPosition.z > 1 ||
           -cameraSpaceVectorPosition.z > far * 1.4f ||
           -cameraSpaceVectorPosition.z < 0.0f)
        {
		   break;
		}

        vec2 samplePos = currentPosition.xy;
        float sampleDepth = convertScreenSpaceToWorldSpace(samplePos).z;

        float currentDepth = cameraSpaceVectorPosition.z;
        float diff = sampleDepth - currentDepth;
        float error = length(cameraSpaceVector / pow(2.0f, numRefinements));

        //If a collision was detected, refine raymarch
        if(diff >= 0 && diff <= error * 2.00f && numRefinements <= maxRefinements)
        {
        	//Step back
        	cameraSpaceVectorPosition -= cameraSpaceVector / pow(2.0f, numRefinements);
        	++numRefinements;
		//If refinements run out
		}
		else if (diff >= 0 && diff <= error * 4.0f && numRefinements > maxRefinements)
		{
			finalSamplePos = samplePos;
			break;
		}



        cameraSpaceVectorPosition += cameraSpaceVector / pow(2.0f, numRefinements);

        if (numSteps > 1)
        cameraSpaceVector *= 1.375f;	//Each step gets bigger

		currentPosition = convertCameraSpaceToScreenSpace(cameraSpaceVectorPosition);
        count++;
        numSteps++;
    }

		#ifdef GODRAYS
			color = pow(texture2DLod(gcolor, finalSamplePos, 0), vec4(2.2f)); color.a = 1.0;
		#endif

		#ifdef NO_GODRAYS
			color = pow(texture2DLod(gcolor, finalSamplePos, 0), vec4(2.2f));
		#endif
	if (finalSamplePos.x == 0.0f || finalSamplePos.y == 0.0f) {
		color.a = 0.0f;
	}

	if (GetSkyMask(finalSamplePos))
		color.a = 0.0f;

	// if (GetWaterMask(finalSamplePos))
	// 	color.a = 0.0f;

	color.a *= clamp(1 - pow(distance(vec2(0.5), finalSamplePos)*2.0, 2.0), 0.0, 1.0);
	// color.a *= 1.0f - float(GetMaterialMask(finalSamplePos, 0, surface.mask.matIDs));

	//surface.color = vec3(numSteps / 10000000.0f);

    return color;
}

float 	CalculateLuminance(in vec3 color) {
	return (color.r * 0.2126f + color.g * 0.7152f + color.b * 0.0722f);
}

float   CalculateSunglow(in SurfaceStruct surface) {

	float curve = 4.0f;

	vec3 npos = normalize(surface.viewSpacePosition.xyz);
	vec3 halfVector2 = normalize(-surface.lightVector + npos);
	float factor = 1.0f - dot(halfVector2, npos);

	return factor * factor * factor * factor;
}

float   CalculateReflectedSunglow(in SurfaceStruct surface) {

	float curve = 4.0f;

	vec3 npos = normalize(surface.viewSpacePosition.xyz);
	surface.lightVector = reflect(surface.lightVector, surface.normal);
	vec3 halfVector2 = normalize(-surface.lightVector + npos);
	float factor = 1.0f - dot(halfVector2, npos);

	return factor * factor * factor * factor;
}

float   CalculateAntiSunglow(in SurfaceStruct surface) {

	float curve = 4.0f;

	vec3 npos = normalize(surface.viewSpacePosition.xyz);
	vec3 halfVector2 = normalize(surface.lightVector + npos);
	float factor = 1.0f - dot(halfVector2, npos);

	return factor * factor * factor * factor;
}

float   CalculateSunspot(in SurfaceStruct surface) {

	float curve = 1.0f;

	vec3 npos = normalize(surface.viewSpacePosition.xyz);
	vec3 halfVector2 = normalize(-surface.lightVector + npos);

	float sunProximity = abs(1.0f - dot(halfVector2, npos));

	//surface.roughness = 0.5f;

	float sizeFactor = 0.959f - surface.roughness * 0.7f;

	float sunSpot = (clamp(sunProximity, sizeFactor, 0.96f) - sizeFactor) / (0.96f - sizeFactor);
		  sunSpot = pow(cubicPulse(1.0f, 1.0f, sunSpot), 2.0f);

	// if (sunProximity > 0.96f) {
	// 	return 1.0f;
	// } else {
	// 	return 0.0f;
	// }

	float result = sunSpot / (surface.roughness * 20.0f + 0.1f);

		  result *= surface.sunlightVisibility;

	return result;
	//return 0.0f;
}

vec3 	ComputeReflectedSkyGradient(in SurfaceStruct surface) {
	float curve = 5.0f;
	surface.viewSpacePosition.xyz = reflect(surface.viewSpacePosition.xyz, surface.normal);
	vec3 npos = normalize(surface.viewSpacePosition.xyz);

	//surface.upVector = reflect(upVector, surface.normal);
	//surface.lightVector = reflect(lightVector, surface.normal);

	vec3 halfVector2 = normalize(-surface.upVector + npos);
	float skyGradientFactor = dot(halfVector2, npos);
	float skyGradientRaw = skyGradientFactor;
	float skyDirectionGradient = skyGradientFactor;

	if (dot(halfVector2, npos) > 0.75)
		skyGradientFactor = 1.5f - skyGradientFactor;

	skyGradientFactor = pow(skyGradientFactor, curve);

	vec3 skyColor = CalculateLuminance(pow(gl_Fog.color.rgb, vec3(2.2f))) * colorSkylight;

	skyColor *= mix(skyGradientFactor, 1.0f, clamp((0.12f - (timeNoon * 0.1f)) + rainStrength, 0.0f, 1.0f));
	skyColor *= pow(skyGradientFactor, 2.5f) + 0.2f;
	skyColor *= (pow(skyGradientFactor, 1.1f) + 0.425f) * 0.5f;
	skyColor.g *= skyGradientFactor * 3.0f + 1.0f;


	vec3 linFogColor = pow(gl_Fog.color.rgb, vec3(2.2f));

	float fogLum = max(max(linFogColor.r, linFogColor.g), linFogColor.b);


	float fadeSize = 0.0f;

	float fade1 = clamp(skyGradientFactor - 0.05f, 0.0f, 0.2f) / 0.2f;
		  fade1 = fade1 * fade1 * (3.0f - 2.0f * fade1);
	vec3 color1 = vec3(12.0f, 8.0, 4.7f) * 0.15f;
		 color1 = mix(color1, vec3(2.0f, 0.55f, 0.2f), vec3(timeSunriseSunset));

	skyColor *= mix(vec3(1.0f), color1, vec3(fade1));

	float fade2 = clamp(skyGradientFactor - 0.11f, 0.0f, 0.2f) / 0.2f;
	vec3 color2 = vec3(2.7f, 1.0f, 2.8f) / 20.0f;
		 color2 = mix(color2, vec3(1.0f, 0.15f, 0.5f), vec3(timeSunriseSunset));


	skyColor *= mix(vec3(1.0f), color2, vec3(fade2 * 0.5f));




	float horizonGradient = 1.0f - distance(skyDirectionGradient, 0.72f + fadeSize) / (0.72f + fadeSize);
		  horizonGradient = pow(horizonGradient, 10.0f);
		  horizonGradient = max(0.0f, horizonGradient);

	float sunglow = CalculateSunglow(surface);
		  horizonGradient *= sunglow * 2.0f+ (0.65f - timeSunriseSunset * 0.55f);

	vec3 horizonColor1 = vec3(1.5f, 1.5f, 1.5f);
		 horizonColor1 = mix(horizonColor1, vec3(1.5f, 1.95f, 1.5f) * 2.0f, vec3(timeSunriseSunset));
	vec3 horizonColor2 = vec3(1.5f, 1.2f, 0.8f) * 1.0f;
		 horizonColor2 = mix(horizonColor2, vec3(1.9f, 0.6f, 0.4f) * 2.0f, vec3(timeSunriseSunset));

	skyColor *= mix(vec3(1.0f), horizonColor1, vec3(horizonGradient) * (1.0f - timeMidnight));
	skyColor *= mix(vec3(1.0f), horizonColor2, vec3(pow(horizonGradient, 2.0f)) * (1.0f - timeMidnight));

	float grayscale = fogLum / 20.0f;
		  grayscale /= 3.0f;

	float rainSkyBrightness = 1.2f;
		  rainSkyBrightness *= mix(0.05f, 10.0f, timeMidnight);

	skyColor = mix(skyColor, vec3(grayscale * colorSkylight.r) * 0.06f * vec3(0.85f, 0.85f, 1.0f), vec3(rainStrength));


	skyColor /= fogLum;


	float antiSunglow = CalculateAntiSunglow(surface);

	skyColor *= 1.0f + pow(sunglow, 1.1f) * (7.0f + timeNoon * 1.0f) * (1.0f - rainStrength);
	skyColor *= mix(vec3(1.0f), colorSunlight * 11.0f, clamp(vec3(sunglow) * (1.0f - timeMidnight) * (1.0f - rainStrength), vec3(0.0f), vec3(1.0f)));
	skyColor *= 1.0f + antiSunglow * 2.0f * (1.0f - rainStrength);


	if (surface.mask.water)
	{
		vec3 sunspot = vec3(CalculateSunspot(surface)) * colorSunlight;
			 sunspot *= 50.0f;
			 sunspot *= 1.0f - timeMidnight;
			 sunspot *= 1.0f - rainStrength;


		skyColor += sunspot;
	}

	skyColor *= pow(1.0f - clamp(skyGradientRaw - 0.75f, 0.0f, 0.25f) / 0.25f, 3.0f);

	skyColor *= mix(1.0f, 4.5f, timeNoon);


	return skyColor;
}

Intersection 	RayPlaneIntersectionWorld(in Ray ray, in Plane plane)
{
	float rayPlaneAngle = dot(ray.dir, plane.normal);

	float planeRayDist = 100000000.0f;
	vec3 intersectionPos = ray.dir * planeRayDist;

	if (rayPlaneAngle > 0.0001f || rayPlaneAngle < -0.0001f)
	{
		planeRayDist = dot((plane.origin), plane.normal) / rayPlaneAngle;
		intersectionPos = ray.dir * planeRayDist;
		intersectionPos = -intersectionPos;

		intersectionPos += cameraPosition.xyz;
	}

	Intersection i;

	i.pos = intersectionPos;
	i.distance = planeRayDist;
	i.angle = rayPlaneAngle;

	return i;
}

Intersection 	RayPlaneIntersection(in Ray ray, in Plane plane)
{
	float rayPlaneAngle = dot(ray.dir, plane.normal);

	float planeRayDist = 100000000.0f;
	vec3 intersectionPos = ray.dir * planeRayDist;

	if (rayPlaneAngle > 0.0001f || rayPlaneAngle < -0.0001f)
	{
		planeRayDist = dot((plane.origin - ray.origin), plane.normal) / rayPlaneAngle;
		intersectionPos = ray.origin + ray.dir * planeRayDist;
		// intersectionPos = -intersectionPos;

		// intersectionPos += cameraPosition.xyz;
	}

	Intersection i;

	i.pos = intersectionPos;
	i.distance = planeRayDist;
	i.angle = rayPlaneAngle;

	return i;
}


float GetCoverage(in float coverage, in float density, in float clouds)
{
	clouds = clamp(clouds - (1.0f - coverage), 0.0f, 1.0f -density) / (1.0f - density);
		clouds = max(0.0f, clouds * 1.1f - 0.1f);
	 clouds = clouds = clouds * clouds * (3.0f - 2.0f * clouds);
	 // clouds = pow(clouds, 1.0f);
	return clouds;
}

vec4 CloudColor(in vec4 worldPosition, in float sunglow, in vec3 worldLightVector, in float altitude, in float thickness)
{

	float cloudHeight = altitude;
	float cloudDepth  = thickness;
	float cloudUpperHeight = cloudHeight + (cloudDepth / 2.0f);
	float cloudLowerHeight = cloudHeight - (cloudDepth / 2.0f);

	worldPosition.xz /= 1.0f + max(0.0f, length(worldPosition.xz - cameraPosition.xz) / 3000.0f);

	vec3 p = worldPosition.xyz / 300.0f;




	float t = frameTimeCounter * 0.0f;
		  //t *= 0.001;
	p.x -= t * 0.01f;

	 p += (Get3DNoise(p * 1.0f + vec3(0.0f, t * 0.01f, 0.0f)) * 2.0f - 1.0f) * 0.3f;

	vec3 p1 = p * vec3(1.0f, 0.5f, 1.0f)  + vec3(0.0f, t * 0.01f, 0.0f);
	float noise  = 	Get3DNoise(p * vec3(1.0f, 0.5f, 1.0f) + vec3(0.0f, t * 0.01f, 0.0f));	p *= 2.0f;	p.x -= t * 0.057f;	vec3 p2 = p;
		  noise += (1.0f - abs(Get3DNoise(p) * 1.0f - 0.5f)) * 0.15f;						p *= 3.0f;	p.xz -= t * 0.035f;	vec3 p3 = p;
		  noise += (1.0f - abs(Get3DNoise(p) * 3.0f - 0.0f)) * 0.045f;						p *= 3.0f;	p.xz -= t * 0.035f;	vec3 p4 = p;
		  noise += (1.0f - abs(Get3DNoise(p) * 3.0f - 0.0f)) * 0.015f;						p *= 3.0f;	p.xz -= t * 0.035f;
		  noise += ((Get3DNoise(p))) * 0.015f;												p *= 3.0f;
		  noise += ((Get3DNoise(p))) * 0.006f;
		  noise /= 1.175f;



	const float lightOffset = 0.2f;


	float heightGradient = clamp(( - (cloudLowerHeight - worldPosition.y) / (cloudDepth * 1.0f)), 0.0f, 1.0f);
	float heightGradient2 = clamp(( - (cloudLowerHeight - (worldPosition.y + worldLightVector.y * lightOffset * 50.0f)) / (cloudDepth * 1.0f)), 0.0f, 1.0f);

	float cloudAltitudeWeight = 1.0f;

	float cloudAltitudeWeight2 = 1.0f;

	noise *= cloudAltitudeWeight;

	//cloud edge
	float coverage = 0.39f;
		  coverage = mix(coverage, 0.77f, rainStrength);

		  float dist = length(worldPosition.xz - cameraPosition.xz);
		  coverage *= max(0.0f, 1.0f - dist / 40000.0f);
	float density = 0.8f;
	noise = GetCoverage(coverage, density, noise);




	float sundiff = Get3DNoise(p1 + worldLightVector.xyz * lightOffset);
		  sundiff += Get3DNoise(p2 + worldLightVector.xyz * lightOffset / 2.0f) * 0.15f;
		  				float largeSundiff = sundiff;
		  				      largeSundiff = -GetCoverage(coverage, 0.0f, largeSundiff * 1.3f);
		  sundiff += Get3DNoise(p3 + worldLightVector.xyz * lightOffset / 5.0f) * 0.045f;
		  sundiff += Get3DNoise(p4 + worldLightVector.xyz * lightOffset / 8.0f) * 0.015f;
		  sundiff *= 1.3f;
		  sundiff *= cloudAltitudeWeight2;
		  sundiff = -GetCoverage(coverage * 1.0f, 0.0f, sundiff);
	float firstOrder 	= pow(clamp(sundiff * 1.0f + 1.1f, 0.0f, 1.0f), 12.0f);
	float secondOrder 	= pow(clamp(largeSundiff * 1.0f + 0.9f, 0.0f, 1.0f), 3.0f);



	float directLightFalloff = mix(firstOrder, secondOrder, 0.1f);
	float anisoBackFactor = mix(clamp(pow(noise, 1.6f) * 2.5f, 0.0f, 1.0f), 1.0f, pow(sunglow, 1.0f));

		  directLightFalloff *= anisoBackFactor;
	 	  directLightFalloff *= mix(11.5f, 1.0f, pow(sunglow, 0.5f));



	vec3 colorDirect = colorSunlight * 0.815f;
		 colorDirect = mix(colorDirect, colorDirect * vec3(0.2f, 0.5f, 1.0f), timeMidnight);
		 colorDirect *= 1.0f + pow(sunglow, 2.0f) * 300.0f * pow(directLightFalloff, 1.1f) * (1.0f - rainStrength);


	vec3 colorAmbient = mix(colorSkylight, colorSunlight * 2.0f, vec3(heightGradient * 0.0f + 0.15f)) * 0.36f;
		 colorAmbient *= mix(1.0f, 0.3f, timeMidnight);
		 colorAmbient = mix(colorAmbient, colorAmbient * 3.0f + colorSunlight * 0.05f, vec3(clamp(pow(1.0f - noise, 12.0f) * 1.0f, 0.0f, 1.0f)));
		 colorAmbient *= heightGradient * heightGradient + 0.1f;

	 vec3 colorBounced = colorBouncedSunlight * 0.1f;
	 	 colorBounced *= pow((1.0f - heightGradient), 8.0f);


	directLightFalloff *= 1.0f;
	//directLightFalloff += pow(Get3DNoise(p3), 2.0f) * 0.05f + pow(Get3DNoise(p4), 2.0f) * 0.015f;

	vec3 color = mix(colorAmbient, colorDirect, vec3(min(1.0f, directLightFalloff)));

	color *= 1.0f;

	vec4 result = vec4(color.rgb, noise);

	return result;

}

vec4 CloudColor2(in vec4 worldPosition, in float sunglow, in vec3 worldLightVector, in float altitude, in float thickness, const bool isShadowPass)
{

	float cloudHeight = altitude;
	float cloudDepth  = thickness;
	float cloudUpperHeight = cloudHeight + (cloudDepth / 3.1f);
	float cloudLowerHeight = cloudHeight - (cloudDepth / 3.1f);

	//worldPosition.xz /= 1.0f + max(0.0f, length(worldPosition.xz - cameraPosition.xz) / 9001.0f);

	vec3 p = worldPosition.xyz / 100.0f;



	float t = FRAME_TIME * 1.0f;
		  t *= 0.4;


	 p += (Get3DNoise(p * 2.0f + vec3(0.0f, t * 0.01f, 0.0f)) * 2.0f - 1.0f) * 0.10f;

	  p.x -= (Get3DNoise(p * 0.125f + vec3(0.0f, t * 0.01f, 0.0f)) * 2.0f - 1.0f) * 1.2f;
	// p.xz -= (Get3DNoise(p * 0.0525f + vec3(0.0f, t * 0.01f, 0.0f)) * 2.0f - 1.0f) * 1.7f;


	p.x *= 0.25f;
	p.x -= t * 0.01f;

	vec3 p1 = p * vec3(1.0f, 0.5f, 1.0f)  + vec3(0.0f, t * 0.01f, 0.0f);
	float noise  = 	Get3DNoise(p * vec3(1.0f, 0.5f, 1.0f) + vec3(0.0f, t * 0.01f, 0.0f));	p *= 2.0f;	p.x -= t * 0.017f;	p.z += noise * 1.35f;	p.x += noise * 0.5f; 									vec3 p2 = p;
		  noise += (2.0f - abs(Get3DNoise(p) * 2.0f - 0.0f)) * (0.25f);						p *= 3.0f;	p.xz -= t * 0.005f;	p.z += noise * 1.35f;	p.x += noise * 0.5f; 	p.x *= 3.0f;	p.z *= 0.55f;	vec3 p3 = p;
		 	 p.z -= (Get3DNoise(p * 0.25f + vec3(0.0f, t * 0.01f, 0.0f)) * 2.0f - 1.0f) * 0.4f;
		  noise += (3.0f - abs(Get3DNoise(p) * 3.0f - 0.0f)) * (0.045f);					p *= 3.0f;	p.xz -= t * 0.005f;																					vec3 p4 = p;
		  noise += (3.0f - abs(Get3DNoise(p) * 3.0f - 0.0f)) * (0.025f);					p *= 3.0f;	p.xz -= t * 0.005f;
		  if (!isShadowPass)
		  {
		 		noise += ((Get3DNoise(p))) * (0.022f);												p *= 3.0f;
		  		 noise += ((Get3DNoise(p))) * (0.014f);
		  }
		  noise /= 1.575f;

	//cloud edge
	float rainy = mix(wetness, 1.0f, rainStrength);
		  //rainy = 0.0f;
	float coverage = 0.55f + rainy * 0.35f;
		  //coverage = mix(coverage, 0.97f, rainStrength);

		  float dist = length(worldPosition.xz - cameraPosition.xz);
		  coverage *= max(0.0f, 1.0f - dist / mix(10000.0f, 3000.0f, rainStrength));
	float density = 0.0f;

	if (isShadowPass)
	{
		return vec4(GetCoverage(coverage + 0.2f, density + 0.2f, noise));
	}
	else
	{

		noise = GetCoverage(coverage, density, noise);
		noise = noise * noise * (3.0f - 2.0f * noise);

		const float lightOffset = 0.2f;



		float sundiff = Get3DNoise(p1 + worldLightVector.xyz * lightOffset);
			  sundiff += (2.0f - abs(Get3DNoise(p2 + worldLightVector.xyz * lightOffset / 2.0f) * 2.0f - 0.0f)) * (0.55f);
			  				float largeSundiff = sundiff;
			  				      largeSundiff = -GetCoverage(coverage, 0.0f, largeSundiff * 1.3f);
			  sundiff += (3.0f - abs(Get3DNoise(p3 + worldLightVector.xyz * lightOffset / 5.0f) * 3.0f - 0.0f)) * (0.065f);
			  sundiff += (3.0f - abs(Get3DNoise(p4 + worldLightVector.xyz * lightOffset / 8.0f) * 3.0f - 0.0f)) * (0.025f);
			  sundiff /= 1.5f;
			  sundiff = -GetCoverage(coverage * 1.0f, 0.0f, sundiff);
		float secondOrder 	= pow(clamp(sundiff * 1.00f + 1.35f, 0.0f, 1.0f), 7.0f);
		float firstOrder 	= pow(clamp(largeSundiff * 1.1f + 1.56f, 0.0f, 1.0f), 3.0f);



		float directLightFalloff = secondOrder;
		float anisoBackFactor = mix(clamp(pow(noise, 1.6f) * 2.5f, 0.0f, 1.0f), 1.0f, pow(sunglow, 1.0f));

			  directLightFalloff *= anisoBackFactor;
		 	  directLightFalloff *= mix(11.5f, 1.0f, pow(sunglow, 0.5f));



		vec3 colorDirect = colorSunlight * 1.915f;
			 colorDirect = mix(colorDirect, colorDirect * vec3(0.2f, 0.5f, 1.0f), timeMidnight);
			 colorDirect *= 1.0f + pow(sunglow, 2.0f) * 100.0f * pow(directLightFalloff, 1.1f) * (1.0f - rainStrength);
			 // colorDirect *= 1.0f + pow(1.0f - sunglow, 2.0f) * 30.0f * pow(directLightFalloff, 1.1f) * (1.0f - rainStrength);


		vec3 colorAmbient = mix(colorSkylight, colorSunlight * 2.0f, vec3(0.15f)) * 0.04f;
			 colorAmbient *= mix(1.0f, 0.3f, timeMidnight);
			 colorAmbient *= mix(1.0f, ((1.0f - noise) + 0.5f) * 1.4f, rainStrength);
			 // colorAmbient = mix(colorAmbient, colorAmbient * 3.0f + colorSunlight * 0.05f, vec3(clamp(pow(1.0f - noise, 12.0f) * 1.0f, 0.0f, 1.0f)));


		directLightFalloff *= 1.0f - rainStrength * 0.9f;


		//directLightFalloff += (pow(Get3DNoise(p3), 2.0f) * 0.5f + pow(Get3DNoise(p3 * 1.5f), 2.0f) * 0.25f) * 0.02f;
		//directLightFalloff *= Get3DNoise(p2);

		vec3 color = mix(colorAmbient, colorDirect, vec3(min(1.0f, directLightFalloff)));

		color *= 1.0f;

		// noise *= mix(1.0f, 5.0f, sunglow);

		vec4 result = vec4(color, noise);

		return result;
	}

}
void ReflectedCloudPlane(inout vec3 color, inout SurfaceStruct surface)
{
	//Initialize view ray
	vec3 viewVector = normalize(surface.viewSpacePosition.xyz);
		 viewVector = reflect(viewVector, surface.normal.xyz);
	vec4 worldVector = gbufferModelViewInverse * (vec4(-viewVector.xyz, 0.0f));

	surface.viewRay.dir = normalize(worldVector.zyx);
	surface.viewRay.origin = vec3(0.0f);

	float sunglow = CalculateReflectedSunglow(surface);


	float cloudsAltitude = 540.0f;
	float cloudsThickness = 150.0f;

	float cloudsUpperLimit = cloudsAltitude + cloudsThickness * 0.5f;
	float cloudsLowerLimit = cloudsAltitude - cloudsThickness * 0.5f;

	float density = 0.251;

	float planeHeight = cloudsUpperLimit;
	float stepSize = 25.5f;
	planeHeight -= cloudsThickness * 0.85f;

	Plane pl;
	pl.origin = vec3(0.0f, cameraPosition.y - planeHeight, 0.0f);
	pl.normal = vec3(0.0f, 1.0f, 0.0f);

	Intersection i = RayPlaneIntersectionWorld(surface.viewRay, pl);

	if (i.angle < 0.0f)
	{
			vec4 cloudSample = CloudColor2(vec4(i.pos.xyz * 0.5f + vec3(30.0f), 1.0f), sunglow, surface.worldLightVector, cloudsAltitude, cloudsThickness, false);
	    	 cloudSample.a = min(1.0f, cloudSample.a * density);

			color.rgb = mix(color.rgb, cloudSample.rgb * 0.18f, cloudSample.a);

			cloudSample = CloudColor2(vec4(i.pos.xyz * 0.65f + vec3(10.0f) + vec3(i.pos.z * 0.5f, 0.0f, 0.0f), 1.0f), sunglow, surface.worldLightVector, cloudsAltitude, cloudsThickness, false);
			cloudSample.a = min(1.0f, cloudSample.a * density);

			color.rgb = mix(color.rgb, cloudSample.rgb * 0.18f, cloudSample.a);

	}

}

float CloudShadow(in SurfaceStruct surface)
{
	float cloudsAltitude = 603.0f;
	float cloudsThickness = 150.0f;

	float cloudsUpperLimit = cloudsAltitude + cloudsThickness * 0.5f;
	float cloudsLowerLimit = cloudsAltitude - cloudsThickness * 0.5f;

	float planeHeight = cloudsUpperLimit;

	planeHeight -= cloudsThickness * 0.85f;

	Plane pl;
	pl.origin = vec3(0.0f, planeHeight, 0.0f);
	pl.normal = vec3(0.0f, 1.0f, 0.0f);

	//Cloud shadow
	Ray surfaceToSun;
	vec4 sunDir = gbufferModelViewInverse * vec4(surface.lightVector, 0.0f);
	surfaceToSun.dir = normalize(sunDir.xyz);
	vec4 surfacePos = gbufferModelViewInverse * surface.screenSpacePosition;
	surfaceToSun.origin = surfacePos.xyz + cameraPosition.xyz;

	Intersection i = RayPlaneIntersection(surfaceToSun, pl);

	float cloudShadow = CloudColor2(vec4(i.pos.xyz * 0.5f + vec3(30.0f), 1.0f), 0.0f, vec3(1.0f), cloudsAltitude, cloudsThickness, true).x;
		  cloudShadow += CloudColor2(vec4(i.pos.xyz * 0.65f + vec3(10.0f) + vec3(i.pos.z * 0.5f, 0.0f, 0.0f), 1.0f), 0.0f, vec3(1.0f), cloudsAltitude, cloudsThickness, true).x;

		  cloudShadow = min(cloudShadow, 1.0f);
		  cloudShadow = 1.0f - cloudShadow;

	return cloudShadow;
	// return 1.0f;
}

void 	AddSkyGradient(inout SurfaceStruct surface) {
	float curve = 5.0f;
	vec3 npos = normalize(surface.screenSpacePosition.xyz);
	vec3 halfVector2 = normalize(-surface.upVector + npos);
	float skyGradientFactor = dot(halfVector2, npos);
	float skyDirectionGradient = skyGradientFactor;

	if (dot(halfVector2, npos) > 0.75)
		skyGradientFactor = 1.5f - skyGradientFactor;

	skyGradientFactor = pow(skyGradientFactor, curve);

	surface.sky.albedo = CalculateLuminance(surface.sky.albedo) * colorSkylight;

	surface.sky.albedo *= mix(skyGradientFactor, 1.0f, clamp((0.12f - (timeNoon * 0.1f)) + rainStrength, 0.0f, 1.0f));
	surface.sky.albedo *= pow(skyGradientFactor, 2.5f) + 0.2f;
	surface.sky.albedo *= (pow(skyGradientFactor, 1.1f) + 0.425f) * 0.5f;
	surface.sky.albedo.g *= skyGradientFactor * 1.0f + 1.0f;


	vec3 linFogColor = pow(gl_Fog.color.rgb, vec3(2.2f));

	float fogLum = max(max(linFogColor.r, linFogColor.g), linFogColor.b);


	float fade1 = clamp(skyGradientFactor - 0.05f, 0.0f, 0.2f) / 0.2f;
		  fade1 = fade1 * fade1 * (3.0f - 2.0f * fade1);
	vec3 color1 = vec3(12.0f, 8.0, 4.7f) * 0.15f;
		 color1 = mix(color1, vec3(2.0f, 0.55f, 0.2f), vec3(timeSunriseSunset));

	surface.sky.albedo *= mix(vec3(1.0f), color1, vec3(fade1));

	float fade2 = clamp(skyGradientFactor - 0.11f, 0.0f, 0.2f) / 0.2f;
	vec3 color2 = vec3(2.7f, 1.0f, 2.8f) / 20.0f;
		 color2 = mix(color2, vec3(1.0f, 0.15f, 0.5f), vec3(timeSunriseSunset));

	surface.sky.albedo *= mix(vec3(1.0f), color2, vec3(fade2 * 0.5f));



	float horizonGradient = 1.0f - distance(skyDirectionGradient, 0.72f) / 0.72f;
		  horizonGradient = pow(horizonGradient, 10.0f);
		  horizonGradient = max(0.0f, horizonGradient);

	float sunglow = CalculateSunglow(surface);
		  horizonGradient *= sunglow * 2.0f + (0.65f - timeSunriseSunset * 0.55f);

	vec3 horizonColor1 = vec3(1.5f, 1.5f, 1.5f);
		 horizonColor1 = mix(horizonColor1, vec3(1.5f, 1.95f, 1.5f) * 2.0f, vec3(timeSunriseSunset));
	vec3 horizonColor2 = vec3(1.5f, 1.2f, 0.8f) * 1.0f;
		 horizonColor2 = mix(horizonColor2, vec3(1.9f, 0.6f, 0.4f) * 2.0f, vec3(timeSunriseSunset));

	surface.sky.albedo *= mix(vec3(1.0f), horizonColor1, vec3(horizonGradient) * (1.0f - timeMidnight));
	surface.sky.albedo *= mix(vec3(1.0f), horizonColor2, vec3(pow(horizonGradient, 2.0f)) * (1.0f - timeMidnight));

	float grayscale = fogLum / 10.0f;
		  grayscale /= 3.0f;

	surface.sky.albedo = mix(surface.sky.albedo, vec3(grayscale * colorSkylight.r) * 0.06f * vec3(0.85f, 0.85f, 1.0f), vec3(rainStrength));


	surface.sky.albedo /= fogLum;


	surface.sky.albedo *= mix(1.0f, 4.5f, timeNoon);



	// //Fake land
	// vec3 fakeLandColor = vec3(0.2f, 0.5f, 1.0f) * 0.006f;
	// surface.sky2.albedo = mix(surface.sky2.albedo, fakeLandColor, vec3(clamp(skyGradientFactor * 8.0f - 0.7f, 0.0f, 1.0f)));


	surface.sky.albedo *= (surface.mask.sky);
}

void 	ReflectedCalculateClouds2 (inout vec3 color, inout SurfaceStruct surface)
{
	//if (texcoord.s < 0.5f && texcoord.t < 0.5f)
	//{
		surface.cloudAlpha = 0.0f;

		vec2 coord = texcoord.st * 2.0f;

		vec4 worldPosition = gbufferModelViewInverse * surface.screenSpacePosition;
			 worldPosition.xyz += cameraPosition.xyz;

		float cloudHeight = 603f;
		float cloudDepth  = 140.0f;
		float cloudDensity = 1.5f;

		if (worldPosition.y < cloudHeight - cloudDepth * 0.5) {
				return;
		}

		float startingRayDepth = far - 5.0f;

		float rayDepth = startingRayDepth;
			  //rayDepth += CalculateDitherPattern1() * 0.85f;
			  //rayDepth += texture2D(noisetex, texcoord.st * (viewWidth / noiseTextureResolution, viewHeight / noiseTextureResolution)).x * 0.1f;
			  //rayDepth += CalculateDitherPattern2() * 0.1f;
		float rayIncrement = far / 10.0f;

			  //rayDepth += CalculateDitherPattern1() * rayIncrement;

		float dither = CalculateDitherPattern2();

		int i = 0;

		vec3 cloudColor = colorSunlight;
		vec4 cloudSum = vec4(0.0f);
			 cloudSum.rgb = colorSkylight * 0.2f;
			 cloudSum.rgb = color.rgb;

		float sunglow = CalculateSunglow(surface);

		float cloudDistanceMult = 800.0f / far;


		float surfaceDistance = length(worldPosition.xyz - cameraPosition.xyz);

		vec4 toEye = gbufferModelView * vec4(0.0f, 0.0f, -1.0f, 0.0f);

		vec4 startPosition = GetCloudSpacePosition(texcoord.st, rayDepth, cloudDistanceMult);

		const int numSteps = 50;
		const float numStepsF = 50.0f;

		// while (rayDepth > 0.0f)
		for (int i = 0; i < numSteps; i++)
		{
			//determine worldspace ray position
			// vec4 rayPosition = GetCloudSpacePosition(texcoord.st, rayDepth, cloudDistanceMult);
			float inormalized = i / numStepsF;
				  inormalized += dither / numStepsF;
				  // inormalized = pow(inormalized, 0.5);
			vec4 rayPosition = vec4(0.0);
			     rayPosition.xyz = mix(startPosition.xyz, cameraPosition.xyz, inormalized);

			float rayDistance = length((rayPosition.xyz - cameraPosition.xyz) / cloudDistanceMult);

			//if (surfaceDistance < rayDistance * cloudDistanceMult && surface.mask.sky < 0.5f) {
				//if(surface.mask.sky2 < 0.5) {
			//		continue;
				//}
			//}

			vec4 proximity =  CloudColor(rayPosition, sunglow, surface.worldLightVector, 1.0, 1.0);
				 proximity.a *= cloudDensity;

				 //proximity.a *=  clamp(surfaceDistance - rayDistance, 0.0f, 1.0f);
				  //if (surfaceDistance < rayDistance * cloudDistanceMult && surface.mask.sky < 0.5f) {
					//	proximity.a = 0.0f;
					//}

				// if((surface.mask.sky < 0.5)) {
				//	 proximity.a *= clamp((surfaceDistance - (rayDistance * cloudDistanceMult)) / rayIncrement, 0.0f, 1.0f);
				 //}

			//cloudSum.rgb = mix( cloudSum.rgb, proximity.rgb, vec3(min(1.0f, proximity.a * cloudDensity)) );
			//cloudSum.a += proximity.a * cloudDensity;
			color.rgb = mix(color.rgb, proximity.rgb, vec3(min(1.0f, proximity.a * cloudDensity)));

			surface.cloudAlpha += proximity.a;

			//Increment ray
			rayDepth -= rayIncrement;

			// if (surface.cloudAlpha >= 1.0)
			// {
			// 	break;
			// }

			 // if (rayDepth * cloudDistanceMult  < ((cloudHeight - (cloudDepth * 0.5)) - cameraPosition.y))
			 // {
			 // 	break;
			 // }
		}

		//color.rgb = mix(color.rgb, cloudSum.rgb, vec3(min(1.0f, cloudSum.a * 20.0f)));
		//color.rgb = cloudSum.rgb;
}

void CloudPlane(inout SurfaceStruct surface)
{
	//Initialize view ray
	vec4 worldVector = gbufferModelViewInverse * (-GetViewSpacePosition(texcoord.st));

	surface.viewRay.dir = normalize(worldVector.xyz);
	surface.viewRay.origin = vec3(0.0f);

	float sunglow = CalculateSunglow(surface);



	float cloudsAltitude = 540.0f;
	float cloudsThickness = 150.0f;

	float cloudsUpperLimit = cloudsAltitude + cloudsThickness * 0.5f;
	float cloudsLowerLimit = cloudsAltitude - cloudsThickness * 0.5f;

	float density = 1.0f;

	float planeHeight = cloudsUpperLimit;
	float stepSize = 25.5f;
	planeHeight -= cloudsThickness * 0.85f;


	Plane pl;
	pl.origin = vec3(0.0f, cameraPosition.y - planeHeight, 0.0f);
	pl.normal = vec3(0.0f, 1.0f, 0.0f);

	Intersection i = RayPlaneIntersectionWorld(surface.viewRay, pl);

	vec3 original = surface.color.rgb;

	if (i.angle < 0.0f)
	{
		if (i.distance < surface.linearDepth || surface.mask.sky)
		{
			vec4 cloudSample = CloudColor2(vec4(i.pos.xyz * 0.5f + vec3(30.0f), 1.0f), sunglow, surface.worldLightVector, cloudsAltitude, cloudsThickness, false);
			 	 cloudSample.a = min(1.0f, cloudSample.a * density);

			surface.color.rgb = mix(surface.color.rgb, cloudSample.rgb * 0.001f, cloudSample.a);

			cloudSample = CloudColor2(vec4(i.pos.xyz * 0.65f + vec3(10.0f) + vec3(i.pos.z * 0.5f, 0.0f, 0.0f), 1.0f), sunglow, surface.worldLightVector, cloudsAltitude, cloudsThickness, false);
			cloudSample.a = min(1.0f, cloudSample.a * density);

			surface.color.rgb = mix(surface.color.rgb, cloudSample.rgb * 0.001f, cloudSample.a);

		}
	}

	surface.color.rgb = mix(surface.color.rgb, original, surface.cloudAlpha);
}

vec4 	ComputeFakeSkyReflection(in SurfaceStruct surface) {

	vec3 cameraSpacePosition = convertScreenSpaceToWorldSpace(texcoord.st);
	vec3 cameraSpaceNormal = surface.normal;
	vec3 cameraSpaceViewDir = normalize(cameraSpacePosition);
	vec4 color = vec4(0.0f);

	color.rgb = ComputeReflectedSkyGradient(surface);
	ReflectedCloudPlane(color.rgb, surface);
	ReflectedCalculateClouds2(color.rgb, surface);
	color.rgb *= 0.006f;
	color.rgb *= mix(1.0f, 20000.0f, timeSkyDark);

	float viewVector = dot(cameraSpaceViewDir, cameraSpaceNormal);

	color.a = pow(clamp(1.0f + viewVector, 0.0f, 1.0f), surface.fresnelPower) * (1.0f - surface.baseSpecularity) + surface.baseSpecularity;

	if (viewVector > 0.0f) {
		color.a = 1.0f - pow(clamp(viewVector, 0.0f, 1.0f), 1.0f / surface.fresnelPower) * (1.0f - surface.baseSpecularity) + surface.baseSpecularity;
		color.rgb = vec3(0.0f);
	}


	DoNightEye(color.rgb);

	color.rgb *= mix(1.0f, 0.125f, timeMidnight);

	return color;
}

void 	CalculateSpecularReflections(inout SurfaceStruct surface) {

	float specularity = surface.specularity * surface.specularity * surface.specularity;
	      specularity = max(0.0f, specularity * 1.15f - 0.15f);
	surface.specularColor = vec3(1.0f);
	//surface.specularity = 1.0f;
	//surface.roughness *= surface.roughness;

	bool defaultItself = false;

	surface.rDepth = 0.0f;

	if (surface.mask.sky)
		specularity = 0.0f;

	if (surface.mask.water)
	{
		specularity = 1.0f;
		surface.roughness = 0.0f;
		surface.fresnelPower = 6.0f;
		surface.baseSpecularity = 0.02f;
	}

	if (surface.mask.ironBlock)
	{
		surface.baseSpecularity = 1.0f;
		//specularity = 1.0f;
		//surface.roughness = 0.0f;
	}

	if (surface.mask.goldBlock)
	{
		//surface.specularity = 1.0f;
		//surface.roughness = 0.4f;
		surface.baseSpecularity = 1.0f;
		surface.specularColor = vec3(1.0f, 0.32f, 0.002f);
		surface.specularColor = mix(surface.specularColor, vec3(1.0f), vec3(0.015f));
	}

	//surface.roughness = 0.0f;

	vec3 original = surface.color.rgb;

	if (specularity > 0.00f) {

		vec3 noise3 = vec3(noise(0.0f), noise(1.0f), noise(2.0f));

		surface.normal += noise3 * 0.00f;

		vec4 reflection = ComputeRaytraceReflection(surface);
		//vec4 reflection = vec4(0.0f);

		float surfaceLightmap = GetLightmapSky(texcoord.st);

		vec4 fakeSkyReflection = ComputeFakeSkyReflection(surface);

		vec3 noSkyToReflect = vec3(0.0f);

		if (defaultItself)
		{
			noSkyToReflect = surface.color.rgb;
		}

		fakeSkyReflection.rgb = mix(noSkyToReflect, fakeSkyReflection.rgb, clamp(surfaceLightmap * 16 - 5, 0.0f, 1.0f));
		reflection.rgb = mix(reflection.rgb, fakeSkyReflection.rgb, pow(vec3(1.0f - reflection.a), vec3(10.1f)));
		reflection.a = fakeSkyReflection.a * specularity;


		reflection.rgb *= surface.specularColor;

		surface.color.rgb = mix(surface.color.rgb, reflection.rgb, vec3(reflection.a));
		surface.reflection = reflection;
	}

	surface.color.rgb = mix(surface.color.rgb, original, vec3(surface.cloudAlpha));
}

void CalculateSpecularHighlight(inout SurfaceStruct surface)
{
	if (!surface.mask.sky && !surface.mask.water)
	{
		//surface.specularity = 0.51f;
		//surface.roughness = 0.2f;

		vec3 halfVector = normalize(lightVector - normalize(surface.viewSpacePosition.xyz));

		float HdotN = max(0.0f, dot(halfVector, surface.normal.xyz));

		//surface.roughness = sin(FRAME_TIME * 3.1415f) * 0.5f + 0.5f;

		float gloss = pow(1.0f - surface.roughness + 0.01f, 4.5f);

		HdotN = clamp(HdotN * (1.0f + gloss * 0.01f), 0.0f, 1.0f);

		float spec = pow(HdotN, gloss * 8000.0f + 10.0f);

		//spec *= float(!surface.mask.sky);

		float fresnel = pow(clamp(1.0f + dot(normalize(surface.viewSpacePosition.xyz), surface.normal.xyz), 0.0f, 1.0f), surface.fresnelPower) * (1.0f - surface.baseSpecularity) + surface.baseSpecularity;


		spec *= fresnel;
		spec *= surface.sunlightVisibility;

		//spec *= pow(1.0f - surface.roughness, 1.5f) * 80000.0f;
		spec *= gloss * 9000.0f + 10.0f;
		spec *= surface.specularity * surface.specularity * surface.specularity;
		spec *= 1.0f - rainStrength;

		vec3 specularHighlight = spec * mix(colorSunlight, vec3(0.2f, 0.5f, 1.0f) * 0.0005f, vec3(timeMidnight)) * surface.specularColor;


		surface.color += specularHighlight / 500.0f;
	}
}

void CalculateGlossySpecularReflections(inout SurfaceStruct surface)
{
	float specularity = surface.specularity;
	float roughness = 0.7f;
	float spread = 0.02f;

	specularity *= 1.0f - float(surface.mask.sky);

	vec4 reflectionSum = vec4(0.0f);

	surface.fresnelPower = 6.0f;
	surface.baseSpecularity = 0.0f;

	if (surface.mask.ironBlock)
	{
		roughness = 0.9f;
		//specularity = 1.0f;
		//surface.baseSpecularity = 1.0f;
	}

	if (surface.mask.goldBlock)
	{
		specularity = 0.0f;
	}



	if (specularity > 0.01f)
	{
		float fresnel = 1.0f - clamp(-dot(normalize(surface.viewSpacePosition.xyz), surface.normal.xyz), 0.0f, 1.0f);

		for (int i = 1; i <= 10; i++)
		{
			vec2 translation = vec2(surface.normal.x, surface.normal.y) * i * spread;
				 translation *= vec2(1.0f, viewWidth / viewHeight);
			//vec2 scaling = (4.0f - vec2(fresnel) * 3.0f);

			float faceFactor = surface.normal.z;
				  faceFactor *= spread * 13.0f;

			vec2 scaling = vec2(1.0f + faceFactor * (i / 10.0f) * 2.0f);

			float r = float(i) + 4.0f;
				  r *= roughness * 0.8f;
			int 	ri = int(floor(r));
			float 	rf = fract(r);

			vec2 finalCoord = (((texcoord.st * 2.0f - 1.0f) * scaling) * 0.5f + 0.5f) + translation;

			float weight = (11 - i + 1) / 10.0f;
			reflectionSum.rgb += pow(texture2DLod(gcolor, finalCoord, r).rgb, vec3(2.2f));
		}



		reflectionSum.rgb /= 10.0f;

		fresnel *= 0.9;
		fresnel = pow(fresnel, surface.fresnelPower);

		surface.color = mix(surface.color, reflectionSum.rgb * 1.0f, vec3(specularity) * fresnel * (1.0f - surface.baseSpecularity) + surface.baseSpecularity);
		}
	//surface.color.rgb *= vec3(1.0f) + reflectionSum.rgb * 400000.2f;
}

vec4 TextureSmooth(in sampler2D tex, in vec2 coord, in int level)
{
	vec2 res = vec2(viewWidth, viewHeight);
	coord = coord * res + 0.5f;
	vec2 i = floor(coord);
	vec2 f = fract(coord);
	f = f * f * (3.0f - 2.0f * f);
	coord = i + f;
	coord = (coord - 0.5f) / res;
	return texture2D(tex, coord, level);
}

void SmoothSky(inout SurfaceStruct surface)
{
	const float cloudHeight = 200.0f;
	const float cloudDepth = 140.0f;
	const float cloudMaxHeight = cloudHeight + cloudDepth / 2.0f;
	const float cloudMinHeight = cloudHeight - cloudDepth / 2.0f;

	float cameraHeight = cameraPosition.y;
	float surfaceHeight = surface.worldSpacePosition.y;

	vec3 combined = pow(TextureSmooth(gcolor, texcoord.st, 2).rgb, vec3(2.2f));
	vec3 original = surface.color;

	// surface.color = combined;

	if (surface.cloudAlpha > 0.000001f)
	{
		surface.color = combined;
	}

	if (cameraHeight < cloudMinHeight && surfaceHeight < cloudMinHeight - 10.0f && surface.mask.land)
	{
		surface.color = original;
	}

	if (cameraHeight > cloudMaxHeight && surfaceHeight > cloudMaxHeight && surface.mask.land)
	{
		surface.color = original;
	}

	if (cameraHeight > cloudMaxHeight - 20.0f)
	{
		surface.color = vec3(0.0);
	}
}


void FixNormals(inout vec3 normal, in vec3 viewPosition)
{
	vec3 V = normalize(viewPosition.xyz);
	vec3 N = normal;

	float NdotV = dot(N, V);

	N = normalize(mix(normal, -V, clamp(pow((NdotV * 1.0), 1.0), 0.0, 1.0)));
	N = normalize(N + -V * 0.1 * clamp(NdotV + 0.4, 0.0, 1.0));

	normal = N;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void main() {

	surface.color = pow(texture2DLod(gcolor, texcoord.st, 0).rgb, vec3(2.2f));
	surface.normal = GetNormals(texcoord.st);
	surface.depth = GetDepth(texcoord.st);
	surface.linearDepth 		= ExpToLinearDepth(surface.depth); 				//Get linear scene depth
	surface.viewSpacePosition = GetViewSpacePosition(texcoord.st);
	surface.worldSpacePosition = gbufferModelViewInverse * surface.viewSpacePosition;
	FixNormals(surface.normal, surface.viewSpacePosition.xyz);
	surface.lightVector = lightVector;
	surface.sunlightVisibility = GetSunlightVisibility(texcoord.st);
	surface.upVector 	= upVector;
	vec4 wlv 					= shadowModelViewInverse * vec4(0.0f, 0.0f, 0.0f, 1.0f);
	surface.worldLightVector 	= normalize(wlv.xyz);

	surface.sky2.albedo 		= GetAlbedoLinear(texcoord.st) * (min(1.0f, (surface.mask.sky2) + (surface.mask.sunspot)));							//Gets the albedo texture for the sky

	surface.specularity = GetSpecularity(texcoord.st);
	surface.roughness = 1.0f - GetRoughness(texcoord.st);
	surface.fresnelPower = 6.0f + surface.roughness * 0.0f;
	surface.baseSpecularity = 0.02f;

	surface.mask.matIDs = GetMaterialIDs(texcoord.st);
	CalculateMasks(surface.mask);

	surface.cloudAlpha = 0.0f;
	#ifdef SMOOTH_SKY
		surface.cloudAlpha = texture2D(composite, texcoord.st, 2).g;
		SmoothSky(surface);
	#endif

//	CloudPlane(surface);
	CalculateSpecularReflections(surface);
	CalculateSpecularHighlight(surface);
	CalculateGlossySpecularReflections(surface);


	vec4 tpos = vec4(sunPosition,1.0)*gbufferProjection;
		tpos = vec4(tpos.xyz/tpos.w,1.0);
		vec2 pos1 = tpos.xy/tpos.z;
		vec2 lightPos = pos1*0.5+0.5;
		float gr = 0.0;

	#ifdef GODRAYS

	#ifdef NO_UNDERWATER_RAYS
	if (isEyeInWater > 0.9) {

		} else {
	#endif

		if (rainStrength > 0.9) {

		} else {

		float truepos = sign(sunPosition.z); //temporary fix that check if the sun/moon position is correct
		if (truepos < 0.05) {
				vec2 deltaTextCoord = vec2( texcoord.st - lightPos.xy );
				vec2 textCoord = texcoord.st;
				deltaTextCoord *= 1.0 / float(NUM_SAMPLES) * grdensity;
				float illuminationDecay = 1.0;
				gr = 0.0;
				float avgdecay = 0.0;
				float distx = abs(texcoord.x*aspectRatio-lightPos.x*aspectRatio);
				float disty = abs(texcoord.y-lightPos.y);
				illuminationDecay = pow(max(1.0-sqrt(distx*distx+disty*disty),0.0),7.8);
				float fallof = 1.0;
				const int nSteps = 9;
				const float blurScale = 0.002;
				deltaTextCoord = normalize(deltaTextCoord);
				int center = (nSteps-1)/2;
				vec3 blur = vec3(0.0);
				float tw = 0.0;
				float sigma = 0.25;
				float A = 1.0/sqrt(2.0*3.14159265359*sigma);
				textCoord -= deltaTextCoord*center*blurScale;

				for(int i=0; i < nSteps ; i++) {
					textCoord += deltaTextCoord*blurScale;
					float dist = (i-float(center))/center;
					float weight = A*exp(-(dist*dist)/(2.0*sigma));
					float sample = texture2D(gcolor, textCoord).a*weight;

					tw += weight;
					gr += sample;
				}

			surface.color.rgb += colorSunlight*exposure*(gr/tw)*(1.0 - rainStrength*0.8)*illuminationDecay;


		}
	#ifdef MOONRAYS
		else {
		tpos = vec4(-sunPosition,1.0)*gbufferProjection;
		tpos = vec4(tpos.xyz/tpos.w,1.0);
		pos1 = tpos.xy/tpos.z;
		lightPos = pos1*0.5+0.5;

			if (truepos > 0.05) {
				vec2 deltaTextCoord = vec2( texcoord.st - lightPos.xy );
				vec2 textCoord = texcoord.st;
				deltaTextCoord *= 1.0 / float(NUM_SAMPLES) * grdensity;
				float illuminationDecay = 1.0;
				gr = 0.0;
				float avgdecay = 0.0;
				float distx = abs(texcoord.x*aspectRatio-lightPos.x*aspectRatio);
				float disty = abs(texcoord.y-lightPos.y);
				illuminationDecay = pow(max(1.0-sqrt(distx*distx+disty*disty),0.0),5.0);
				float fallof = 1.0;
				const int nSteps = 9;
				const float blurScale = 0.002;
				deltaTextCoord = normalize(deltaTextCoord);
				int center = (nSteps-1)/2;
				vec3 blur = vec3(0.0);
				float tw = 0.0;
				float sigma = 0.25;
				float A = 1.0/sqrt(2.0*3.14159265359*sigma);
				textCoord -= deltaTextCoord*center*blurScale;

				for(int i=0; i < nSteps ; i++) {
					textCoord += deltaTextCoord*blurScale;
					float dist = (i-float(center))/center;
					float weight = A*exp(-(dist*dist)/(2.0*sigma));
					float sample = texture2D(gcolor, textCoord).a*weight;

					tw += weight;
					gr += sample;
				}
			surface.color.rgb += 5.0f*colorSunlight*Moon_exposure*(gr/tw)*(1.0 - rainStrength*0.8)*illuminationDecay/2.5*truepos*timeMidnight;
		}
	}
	}
	#endif
	#ifdef NO_UNDERWATER_RAYS
	}
	#endif
	#endif
	// surface.color = surface.normal * 0.0001f;

	//surface.color = vec3(fwidth(surface.depth)) * 0.01f;

	//surface.color.rgb = surface.reflection.rgb;

	// surface.color += vec3(max(0.0, dot(surface.normal, normalize(surface.viewSpacePosition.xyz)))) / 100.0f;

	//surface.color = mix(surface.color, vec3(0.0), vec3(surface.cloudAlpha));

	surface.color = pow(surface.color, vec3(1.0f / 2.2f));
	gl_FragData[0] = vec4(surface.color, 1.0f);
	//gl_FragData[1] = vec4(surface.normal.xyz * 0.5 + 0.5, 1.0f);


}
