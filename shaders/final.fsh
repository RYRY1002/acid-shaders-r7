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

/////////////////////////CONFIGURABLE VARIABLES////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////CONFIGURABLE VARIABLES////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#define SATURATION_BOOST 0.2f 			//How saturated the final image should be. 0 is unchanged saturation. Higher values create more saturated image

//Define one of these, not more, not less.
	//#define TONEMAP_NATURAL // Note: You must have at least one of these settings enabled, not more, not less. Creates a more natural looking look.
	#define TONEMAP_FILMIC // Note: You must have at least one of these settings enabled, not more, not less. Creates a more filmic looking look.

//#define LOCAL_OPERATOR					// Use local operator when tone mapping. Local operators increase image sharpness and local contrast but can cause haloing.

/////////////////////////END OF CONFIGURABLE VARIABLES/////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////END OF CONFIGURABLE VARIABLES/////////////////////////////////////////////////////////////////////////////////////////////////////////////




uniform sampler2D gcolor;
uniform sampler2D gdepth;
uniform sampler2D gdepthtex;
uniform sampler2D gnormal;
uniform sampler2D composite;
uniform sampler2D noisetex;

varying vec4 texcoord;
varying vec3 lightVector;

uniform int worldTime;

uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform float wetness;
uniform float aspectRatio;
uniform float centerDepthSmooth;
uniform float frameTimeCounter;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform int   isEyeInWater;
uniform float eyeAltitude;
uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;
uniform int   fogMode;

varying float timeSunriseSunset;
varying float timeNoon;
varying float timeMidnight;

varying vec3 colorSunlight;
varying vec3 colorSkylight;

#define BANDING_FIX_FACTOR 1.0f




/////////////////////////FUNCTIONS/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////FUNCTIONS/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
vec3 	GetTexture(in sampler2D tex, in vec2 coord) {				//Perform a texture lookup with BANDING_FIX_FACTOR compensation
	return pow(texture2D(tex, coord).rgb, vec3(BANDING_FIX_FACTOR + 1.2f));
}

vec3 	GetTextureLod(in sampler2D tex, in vec2 coord, in int level) {				//Perform a texture lookup with BANDING_FIX_FACTOR compensation
	return pow(texture2DLod(tex, coord, level).rgb, vec3(BANDING_FIX_FACTOR + 1.2f));
}

vec3 	GetTexture(in sampler2D tex, in vec2 coord, in int LOD) {	//Perform a texture lookup with BANDING_FIX_FACTOR compensation and lod offset
	return pow(texture2D(tex, coord, LOD).rgb, vec3(BANDING_FIX_FACTOR));
}

float GetSunlightVisibility(in vec2 coord)
{
	return texture2D(gdepth, coord).g;
}

float 	GetDepth(in vec2 coord) {
	return texture2D(gdepthtex, coord).x;
}

float 	GetDepthLinear(in vec2 coord) {					//Function that retrieves the scene depth. 0 - 1, higher values meaning farther away
	return 2.0f * near * far / (far + near - (2.0f * texture2D(gdepthtex, coord).x - 1.0f) * (far - near));
}

vec3 	GetColorTexture(in vec2 coord) {
	return GetTextureLod(gnormal, coord.st, 0).rgb;
}

float 	GetMaterialIDs(in vec2 coord) {			//Function that retrieves the texture that has all material IDs stored in it
	return texture2D(gdepth, coord).r;
}

vec4  	GetWorldSpacePosition(in vec2 coord) {	//Function that calculates the screen-space position of the objects in the scene using the depth texture and the texture coordinates of the full-screen quad
	float depth = GetDepth(coord);
		  //depth += float(GetMaterialMask(coord, 5)) * 0.38f;
	vec4 fragposition = gbufferProjectionInverse * vec4(coord.s * 2.0f - 1.0f, coord.t * 2.0f - 1.0f, 2.0f * depth - 1.0f, 1.0f);
		 fragposition /= fragposition.w;

	return fragposition;
}

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
	vec2 resolution = vec2(viewWidth, viewHeight);

	coord *= resolution;

	float fx = fract(coord.x);
    float fy = fract(coord.y);
    coord.x -= fx;
    coord.y -= fy;

    fx -= 0.5;
    fy -= 0.5;

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

bool 	GetMaterialMask(in vec2 coord, in int ID) {
	float	  matID = floor(GetMaterialIDs(coord) * 255.0f);

	//Catch last part of sky
	if (matID > 254.0f) {
		matID = 0.0f;
	}

	if (matID == ID) {
		return true;
	} else {
		return false;
	}
}

bool 	GetMaterialMask(in vec2 coord, in int ID, float matID) {
	matID = floor(matID * 255.0f);

	//Catch last part of sky
	if (matID > 254.0f) {
		matID = 0.0f;
	}

	if (matID == ID) {
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

bool  	GetSkyMask(in vec2 coord) {					//Function that returns "true" if a pixel is water, and "false" if a pixel is not water.
	float matID = floor(GetMaterialIDs(coord) * 255.0f);

	if (matID >= 0.1f) {
		return false;
	} else {
		return true;
	}
}

float Luminance(in vec3 color)
{
	return dot(color.rgb, vec3(0.2125f, 0.7154f, 0.0721f));
}

void 	DepthOfField(inout vec3 color)
{

	float cursorDepth = centerDepthSmooth;

	bool isHand = GetMaterialMask(texcoord.st, 5);


	const float blurclamp = 0.014;  // max blur amount
	const float bias = 0.15;	//aperture - bigger values for shallower depth of field


	vec2 aspectcorrect = vec2(1.0, aspectRatio) * 1.5;

	float depth = texture2D(gdepthtex, texcoord.st).x;
		  depth += float(isHand) * 0.36f;

	float factor = (depth - cursorDepth);

	vec2 dofblur = vec2(factor * bias)*0.6;




	vec3 col = vec3(0.0);
	col += GetColorTexture(texcoord.st);

	col += GetColorTexture(texcoord.st + (vec2( 0.0,0.4 )*aspectcorrect) * dofblur);
	col += GetColorTexture(texcoord.st + (vec2( 0.15,0.37 )*aspectcorrect) * dofblur);
	col += GetColorTexture(texcoord.st + (vec2( 0.29,0.29 )*aspectcorrect) * dofblur);
	col += GetColorTexture(texcoord.st + (vec2( -0.37,0.15 )*aspectcorrect) * dofblur);
	col += GetColorTexture(texcoord.st + (vec2( 0.4,0.0 )*aspectcorrect) * dofblur);
	col += GetColorTexture(texcoord.st + (vec2( 0.37,-0.15 )*aspectcorrect) * dofblur);
	col += GetColorTexture(texcoord.st + (vec2( 0.29,-0.29 )*aspectcorrect) * dofblur);
	col += GetColorTexture(texcoord.st + (vec2( -0.15,-0.37 )*aspectcorrect) * dofblur);
	col += GetColorTexture(texcoord.st + (vec2( 0.0,-0.4 )*aspectcorrect) * dofblur);
	col += GetColorTexture(texcoord.st + (vec2( -0.15,0.37 )*aspectcorrect) * dofblur);
	col += GetColorTexture(texcoord.st + (vec2( -0.29,0.29 )*aspectcorrect) * dofblur);
	col += GetColorTexture(texcoord.st + (vec2( 0.37,0.15 )*aspectcorrect) * dofblur);
	col += GetColorTexture(texcoord.st + (vec2( -0.4,0.0 )*aspectcorrect) * dofblur);
	col += GetColorTexture(texcoord.st + (vec2( -0.37,-0.15 )*aspectcorrect) * dofblur);
	col += GetColorTexture(texcoord.st + (vec2( -0.29,-0.29 )*aspectcorrect) * dofblur);
	col += GetColorTexture(texcoord.st + (vec2( 0.15,-0.37 )*aspectcorrect) * dofblur);

	col += GetColorTexture(texcoord.st + (vec2( 0.15,0.37 )*aspectcorrect) * dofblur*0.9);
	col += GetColorTexture(texcoord.st + (vec2( -0.37,0.15 )*aspectcorrect) * dofblur*0.9);
	col += GetColorTexture(texcoord.st + (vec2( 0.37,-0.15 )*aspectcorrect) * dofblur*0.9);
	col += GetColorTexture(texcoord.st + (vec2( -0.15,-0.37 )*aspectcorrect) * dofblur*0.9);
	col += GetColorTexture(texcoord.st + (vec2( -0.15,0.37 )*aspectcorrect) * dofblur*0.9);
	col += GetColorTexture(texcoord.st + (vec2( 0.37,0.15 )*aspectcorrect) * dofblur*0.9);
	col += GetColorTexture(texcoord.st + (vec2( -0.37,-0.15 )*aspectcorrect) * dofblur*0.9);
	col += GetColorTexture(texcoord.st + (vec2( 0.15,-0.37 )*aspectcorrect) * dofblur*0.9);

	col += GetColorTexture(texcoord.st + (vec2( 0.29,0.29 )*aspectcorrect) * dofblur*0.7);
	col += GetColorTexture(texcoord.st + (vec2( 0.4,0.0 )*aspectcorrect) * dofblur*0.7);
	col += GetColorTexture(texcoord.st + (vec2( 0.29,-0.29 )*aspectcorrect) * dofblur*0.7);
	col += GetColorTexture(texcoord.st + (vec2( 0.0,-0.4 )*aspectcorrect) * dofblur*0.7);
	col += GetColorTexture(texcoord.st + (vec2( -0.29,0.29 )*aspectcorrect) * dofblur*0.7);
	col += GetColorTexture(texcoord.st + (vec2( -0.4,0.0 )*aspectcorrect) * dofblur*0.7);
	col += GetColorTexture(texcoord.st + (vec2( -0.29,-0.29 )*aspectcorrect) * dofblur*0.7);
	col += GetColorTexture(texcoord.st + (vec2( 0.0,0.4 )*aspectcorrect) * dofblur*0.7);

	col += GetColorTexture(texcoord.st + (vec2( 0.29,0.29 )*aspectcorrect) * dofblur*0.4);
	col += GetColorTexture(texcoord.st + (vec2( 0.4,0.0 )*aspectcorrect) * dofblur*0.4);
	col += GetColorTexture(texcoord.st + (vec2( 0.29,-0.29 )*aspectcorrect) * dofblur*0.4);
	col += GetColorTexture(texcoord.st + (vec2( 0.0,-0.4 )*aspectcorrect) * dofblur*0.4);
	col += GetColorTexture(texcoord.st + (vec2( -0.29,0.29 )*aspectcorrect) * dofblur*0.4);
	col += GetColorTexture(texcoord.st + (vec2( -0.4,0.0 )*aspectcorrect) * dofblur*0.4);
	col += GetColorTexture(texcoord.st + (vec2( -0.29,-0.29 )*aspectcorrect) * dofblur*0.4);
	col += GetColorTexture(texcoord.st + (vec2( 0.0,0.4 )*aspectcorrect) * dofblur*0.4);

	color = col/41;

}


void 	Vignette(inout vec3 color) {
	float dist = distance(texcoord.st, vec2(0.5f)) * 2.0f;
		  dist /= 1.5142f;

		  //dist = pow(dist, 1.1f);

	color.rgb *= 1.0f - dist;

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

void 	MotionBlur(inout vec3 color) {
	float depth = GetDepth(texcoord.st);
	vec4 currentPosition = vec4(texcoord.x * 2.0f - 1.0f, texcoord.y * 2.0f - 1.0f, 2.0f * depth - 1.0f, 1.0f);

	vec4 fragposition = gbufferProjectionInverse * currentPosition;
	fragposition = gbufferModelViewInverse * fragposition;
	fragposition /= fragposition.w;
	fragposition.xyz += cameraPosition;

	vec4 previousPosition = fragposition;
	previousPosition.xyz -= previousCameraPosition;
	previousPosition = gbufferPreviousModelView * previousPosition;
	previousPosition = gbufferPreviousProjection * previousPosition;
	previousPosition /= previousPosition.w;

	vec2 velocity = (currentPosition - previousPosition).st * 0.12f;
	float maxVelocity = 0.05f;
		 velocity = clamp(velocity, vec2(-maxVelocity), vec2(maxVelocity));


	bool isHand = GetMaterialMask(texcoord.st, 5);
	velocity *= 1.0f - float(isHand);

	int samples = 0;

	float dither = CalculateDitherPattern1();

	color.rgb = vec3(0.0f);

	for (int i = 0; i < 2; ++i) {
		vec2 coord = texcoord.st + velocity * (i - 0.5);
			 coord += vec2(dither) * 1.2f * velocity;

		if (coord.x > 0.0f && coord.x < 1.0f && coord.y > 0.0f && coord.y < 1.0f) {

			color += GetColorTexture(coord).rgb;
			samples += 1;

		}
	}

	color.rgb /= samples;


}

void CalculateExposure(inout vec3 color) {
	float exposureMax = 1.21; // 21 x 2 = 42
		  exposureMax *= mix(1.0f, 0.25f, timeSunriseSunset);
		  exposureMax *= mix(1.0f, 0.0f, timeMidnight);
		  exposureMax *= mix(1.0f, 0.25f, rainStrength);
	float exposureMin = 0.69f;
	float exposure = pow(eyeBrightnessSmooth.y / 240.0f, 6.0f) * exposureMax + exposureMin;

	exposure = 1.25f;

	color.rgb /= vec3(exposure);
}

void TonemapVorontsov(inout vec3 color) {
	//color = pow(color, vec3(2.2f)); 			//Put gcolor back into linear space
	color.rgb *= 75000.0f;

	//Natural
	//Properties
		// float tonemapContrast 		= 0.95f;
		// float tonemapSaturation 	= 1.2f + SATURATION_BOOST;
		// float tonemapDecay			= 210.0f;
		// float tonemapCurve			= 100.0f;

	//Filmic
		float tonemapContrast 		= 0.79f;
		float tonemapSaturation 	= 0.85f;
		float tonemapDecay			= 121000.0f;
		float tonemapCurve			= 1.0f;

	color.rgb += 0.001f;

	vec3 colorN = normalize(color.rgb);

	vec3 clrfr = color.rgb/colorN.rgb;
	     clrfr = pow(clrfr.rgb, vec3(tonemapContrast));

	colorN.rgb = pow(colorN.rgb, vec3(tonemapSaturation));

	color.rgb = clrfr.rgb * colorN.rgb;

	color.rgb = (color.rgb * (1.0 + color.rgb/tonemapDecay))/(color.rgb + tonemapCurve);

	color.rgb = pow(color.rgb, vec3(1.0f / 2.2f));

	color.rgb *= 1.125f;

	color.rgb -= 0.025f;
}

void TonemapReinhard(inout vec3 color) {
	//color.rgb = pow(color.rgb, vec3(2.2f));			//Put color into linear space

	color.rgb *= 100000.0f;
	color.rgb = color.rgb / (1.0f + color.rgb);

	color.rgb = pow(color.rgb, vec3(1.0f / 2.2f)); //Put color into gamma space for correct display
	color.rgb *= 1.0f;
}


void TonemapReinhardLum(inout vec3 color) {
	//color.rgb = pow(color.rgb, vec3(2.2f));			//Put color into linear space

	color.rgb *= 100000.0f;

	float lum = dot(color.rgb, vec3(0.2125f, 0.7154f, 0.0721f));

	float white = 21.0f;
	float lumTonemap = (lum * (1.0f + (lum / white))) / (1.0f + lum);


	float factor = lumTonemap / lum;

	color.rgb *= factor;

	//color.rgb = color.rgb / (color.rgb + 1.0f);

	color.rgb = pow(color.rgb, vec3(1.0f / 2.2f)); //Put color into gamma space for correct display
	color.rgb *= 1.1f;
}


void SaturationBoost(inout vec3 color) {
	float satBoost = 0.07f;

	color.r = color.r * (1.0f + satBoost * 2.0f) - (color.g * satBoost) - (color.b * satBoost);
	color.g = color.g * (1.0f + satBoost * 2.0f) - (color.r * satBoost) - (color.b * satBoost);
	color.b = color.b * (1.0f + satBoost * 2.0f) - (color.r * satBoost) - (color.g * satBoost);
}

void TonemapReinhardLinearHybrid(inout vec3 color) {

	color.rgb *= 25000.0f;
	color.rgb = color.rgb / (1.0f + color.rgb);

	color.rgb = pow(color.rgb, vec3(1.0f / 2.2f)); //Put color into gamma space for correct display
	color.rgb *= 1.21f;
}

void SphericalTonemap(inout vec3 color)
{

	color.rgb = clamp(color.rgb, vec3(0.0f), vec3(1.0f));

	vec3 signedColor = color.rgb * 2.0f - 1.0f;

	vec3 sphericalColor = sqrt(1.0f - signedColor.rgb * signedColor.rgb);
		 sphericalColor = sphericalColor * 0.5f + 0.5f;
		 sphericalColor *= color.rgb;

	float sphericalAmount = 0.3f;

	color.rgb += sphericalColor.rgb * sphericalAmount;
	color.rgb *= 0.95f;
}

void LowtoneSaturate(inout vec3 color)
{
	color.rgb *= 1.125f;
	color.rgb -= 0.125f;
	color.rgb = clamp(color.rgb, vec3(0.0f), vec3(1.0f));
}

void ColorGrading(inout vec3 color)
{
	vec3 c = color.rgb;

	//warm
	c.rgb = max(vec3(0.0f), c.rgb * 1.1f - 0.1f);

		 c.r *= 7.0f;
		 c.r /= c.r + 2.5f;

		 c.g = c.g;

		 c.b *= 0.7f;

	// //cool

	// 	c.r *= 1.0f;
	// 	c.g *= 1.2f;
	// 	c.b *= 1.5f;

	color.rgb = c.rgb;
}

float   CalculateSunspot() {

	float curve = 1.0f;

	vec3 npos = normalize(GetWorldSpacePosition(texcoord.st).xyz);
	vec3 halfVector2 = normalize(-lightVector + npos);

	float sunProximity = 1.0f - dot(halfVector2, npos);

	return clamp(sunProximity - 0.9f, 0.0f, 0.1f) / 0.1f;

	//return sunSpot / (surface.glossiness * 50.0f + 1.0f);
	//return 0.0f;
}

/////////////////////////STRUCTS///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////STRUCTS///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

struct BloomDataStruct
{
	vec3 blur0;
	vec3 blur1;
	vec3 blur2;
	vec3 blur3;
	vec3 blur4;
	vec3 blur5;
	vec3 blur6;

	vec3 bloom;
} bloomData;



struct MaskStruct {

	float matIDs;

	bool sky;
	bool land;
	bool grass;
	bool leaves;
	bool ice;
	bool hand;
	bool translucent;
	bool glow;
	bool sunspot;
	bool goldBlock;
	bool ironBlock;
	bool diamondBlock;
	bool emeraldBlock;
	bool sand;
	bool sandstone;
	bool stone;
	bool cobblestone;
	bool wool;
	bool clouds;

	bool torch;
	bool lava;
	bool glowstone;
	bool fire;

	bool water;

	bool volumeCloud;

} mask;


/////////////////////////STRUCT FUNCTIONS//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////STRUCT FUNCTIONS//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//Mask
void 	CalculateMasks(inout MaskStruct mask) {
		mask.sky 			= GetMaterialMask(texcoord.st, 0, mask.matIDs);
		mask.land	 		= GetMaterialMask(texcoord.st, 1, mask.matIDs);
		mask.grass 			= GetMaterialMask(texcoord.st, 2, mask.matIDs);
		mask.leaves	 		= GetMaterialMask(texcoord.st, 3, mask.matIDs);
		mask.ice		 	= GetMaterialMask(texcoord.st, 4, mask.matIDs);
		mask.hand	 		= GetMaterialMask(texcoord.st, 5, mask.matIDs);
		mask.translucent	= GetMaterialMask(texcoord.st, 6, mask.matIDs);

		mask.glow	 		= GetMaterialMask(texcoord.st, 10, mask.matIDs);
		mask.sunspot 		= GetMaterialMask(texcoord.st, 11, mask.matIDs);

		mask.goldBlock 		= GetMaterialMask(texcoord.st, 20, mask.matIDs);
		mask.ironBlock 		= GetMaterialMask(texcoord.st, 21, mask.matIDs);
		mask.diamondBlock	= GetMaterialMask(texcoord.st, 22, mask.matIDs);
		mask.emeraldBlock	= GetMaterialMask(texcoord.st, 23, mask.matIDs);
		mask.sand	 		= GetMaterialMask(texcoord.st, 24, mask.matIDs);
		mask.sandstone 		= GetMaterialMask(texcoord.st, 25, mask.matIDs);
		mask.stone	 		= GetMaterialMask(texcoord.st, 26, mask.matIDs);
		mask.cobblestone	= GetMaterialMask(texcoord.st, 27, mask.matIDs);
		mask.wool			= GetMaterialMask(texcoord.st, 28, mask.matIDs);
		mask.clouds 		= GetMaterialMask(texcoord.st, 29, mask.matIDs);

		mask.torch 			= GetMaterialMask(texcoord.st, 30, mask.matIDs);
		mask.lava 			= GetMaterialMask(texcoord.st, 31, mask.matIDs);
		mask.glowstone 		= GetMaterialMask(texcoord.st, 32, mask.matIDs);
		mask.fire 			= GetMaterialMask(texcoord.st, 33, mask.matIDs);

		mask.water 			= GetWaterMask(texcoord.st);
}


void 	CalculateBloom(inout BloomDataStruct bloomData) {		//Retrieve previously calculated bloom textures

	//constants for bloom bloomSlant
	const float    bloomSlant = 0.25f;
	const float[7] bloomWeight = float[7] (pow(7.0f, bloomSlant),
										   pow(6.0f, bloomSlant),
										   pow(5.0f, bloomSlant),
										   pow(4.0f, bloomSlant),
										   pow(3.0f, bloomSlant),
										   pow(2.0f, bloomSlant),
										   1.0f
										   );

	vec2 recipres = vec2(1.0f / viewWidth, 1.0f / viewHeight);

	bloomData.blur0  =  pow(texture2D(gcolor, (texcoord.st - recipres * 0.5f) * (1.0f / exp2(2.0f 	)) + 	vec2(0.0f, 0.0f)		+ vec2(0.000f, 0.000f)	).rgb, vec3(1.0f + 1.2f));
	bloomData.blur1  =  pow(texture2D(gcolor, (texcoord.st - recipres * 0.5f) * (1.0f / exp2(3.0f 	)) + 	vec2(0.0f, 0.25f)		+ vec2(0.000f, 0.025f)	).rgb, vec3(1.0f + 1.2f));
	bloomData.blur2  =  pow(texture2D(gcolor, (texcoord.st - recipres * 0.5f) * (1.0f / exp2(4.0f 	)) + 	vec2(0.125f, 0.25f)		+ vec2(0.025f, 0.025f)	).rgb, vec3(1.0f + 1.2f));
	bloomData.blur3  =  pow(texture2D(gcolor, (texcoord.st - recipres * 0.5f) * (1.0f / exp2(5.0f 	)) + 	vec2(0.1875f, 0.25f)	+ vec2(0.050f, 0.025f)	).rgb, vec3(1.0f + 1.2f));
	bloomData.blur4  =  pow(texture2D(gcolor, (texcoord.st - recipres * 0.5f) * (1.0f / exp2(6.0f 	)) + 	vec2(0.21875f, 0.25f)	+ vec2(0.075f, 0.025f)	).rgb, vec3(1.0f + 1.2f));
	bloomData.blur5  =  pow(texture2D(gcolor, (texcoord.st - recipres * 0.5f) * (1.0f / exp2(7.0f 	)) + 	vec2(0.25f, 0.25f)		+ vec2(0.100f, 0.025f)	).rgb, vec3(1.0f + 1.2f));
	bloomData.blur6  =  pow(texture2D(gcolor, (texcoord.st - recipres * 0.5f) * (1.0f / exp2(8.0f 	)) + 	vec2(0.28f, 0.25f)		+ vec2(0.125f, 0.025f)	).rgb, vec3(1.0f + 1.2f));

 	bloomData.bloom  = bloomData.blur0 * bloomWeight[0];
 	bloomData.bloom += bloomData.blur1 * bloomWeight[1];
 	bloomData.bloom += bloomData.blur2 * bloomWeight[2];
 	bloomData.bloom += bloomData.blur3 * bloomWeight[3];
 	bloomData.bloom += bloomData.blur4 * bloomWeight[4];
 	bloomData.bloom += bloomData.blur5 * bloomWeight[5];
 	bloomData.bloom += bloomData.blur6 * bloomWeight[6];

}


void TonemapReinhard07(inout vec3 color, in BloomDataStruct bloomData)
{
	//Per-channel
	// vec3 n = vec3(0.9f);
	// vec3 g = vec3(0.00001f);
	// color.rgb = pow(color.rgb, n) / (pow(color.rgb, n) + pow(g, n));

	//Luminance
	float n = 0.6f;
	float lum = dot(color.rgb, vec3(0.2125f, 0.7154f, 0.0721f));
	float g = 0.000019f + lum * 0.0f;
	float white = 0.1f;
	float compressed = pow((lum * (1.0f + (lum / white))), n) / (pow(lum, n) + pow(g, n));

	float s = clamp(1.0f - compressed * 0.65f, 0.0f, 1.0f) * 0.65f;
	color.r = pow((color.r / lum), s) * (compressed);
	color.g = pow((color.g / lum), s) * (compressed);
	color.b = pow((color.b / lum), s) * (compressed);




	//color.rgb *= 30000.0f;



	color.rgb = pow(color.rgb, vec3(1.0f / 2.2f));
	color.rgb = max(vec3(0.0f), color.rgb * 1.15f - 0.15f);
	color.rgb *= 1.1f;
}


void 	AddRainFogScatter(inout vec3 color, in BloomDataStruct bloomData)
{
	const float    bloomSlant = 0.0f;
	const float[7] bloomWeight = float[7] (pow(7.0f, bloomSlant),
										   pow(6.0f, bloomSlant),
										   pow(5.0f, bloomSlant),
										   pow(4.0f, bloomSlant),
										   pow(3.0f, bloomSlant),
										   pow(2.0f, bloomSlant),
										   1.0f
										   );

	vec3 fogBlur = bloomData.blur0 * bloomWeight[6] +
			       bloomData.blur1 * bloomWeight[5] +
			       bloomData.blur2 * bloomWeight[4] +
			       bloomData.blur3 * bloomWeight[3] +
			       bloomData.blur4 * bloomWeight[2] +
			       bloomData.blur5 * bloomWeight[1] +
			       bloomData.blur6 * bloomWeight[0];

	float fogTotalWeight = 	1.0f * bloomWeight[0] +
			       			1.0f * bloomWeight[1] +
			       			1.0f * bloomWeight[2] +
			       			1.0f * bloomWeight[3] +
			       			1.0f * bloomWeight[4] +
			       			1.0f * bloomWeight[5] +
			       			1.0f * bloomWeight[6];

	fogBlur /= fogTotalWeight;

	float linearDepth = GetDepthLinear(texcoord.st);

	float fogDensity = 0f;
		  //fogDensity += texture2D(composite, texcoord.st).g * 0.1f;
	float visibility = 1.0f / (pow(exp(linearDepth * fogDensity), 1.0f));
	float fogFactor = 1.0f - visibility;
		  fogFactor = clamp(fogFactor, 0.0f, 1.0f);
		  fogFactor *= mix(0.0f, 1.0f, pow(eyeBrightnessSmooth.y / 240.0f, 6.0f));

	// bool waterMask = GetWaterMask(texcoord.st);
	// fogFactor = mix(fogFactor, 0.0f, float(waterMask));

	color = mix(color, fogBlur, fogFactor * 1.0f);
}


void TonemapReinhard05(inout vec3 color, BloomDataStruct bloomData)
{

	//color.b *= 0.85f;

	#ifdef TONEMAP_NATURAL
	float averageLuminance = 0.00010f;
	#endif
	#ifdef TONEMAP_FILMIC
	float averageLuminance = 0.000065f;
	#endif



	#ifdef TONEMAP_NATURAL
	float contrast = 0.85f;
	#endif
	#ifdef TONEMAP_FILMIC
	float contrast = 1.0f;
	#endif

	#ifdef TONEMAP_NATURAL
	float adaptation = 0.75f;
	#endif

	#ifdef TONEMAP_FILMIC
	float adaptation = 0.75f;
	#endif

	float lum = Luminance(color.rgb);
	vec3 blur = bloomData.blur1;
	     blur += bloomData.blur2;

	// float[7] gaussLums = float[7] (	lum,
	// 								Luminance(bloomData.blur0),
	// 							    Luminance(bloomData.blur1),
	// 							   	Luminance(bloomData.blur2),
	// 							   	Luminance(bloomData.blur3),
	// 							   	Luminance(bloomData.blur4),
	// 							   	Luminance(bloomData.blur5));

	// float sMax = gaussLums[3];
	// float e = 0.51f;

	// for (int i = 3; i > 0; i -= 1)
	// {
	// 	float dog = gaussLums[i] - gaussLums[i - 1];
	// 		  dog /= (gaussLums[i - 1] + 0.000000000000000001f);

	// 	if (abs(dog) > e)
	// 		//sMax = mix(sMax, gaussLums[i - 1], clamp(abs(dog) / e, 0.0f, 1.0f));
	// 		//sMax = abs(dog);
	// 		sMax = gaussLums[i - 1];
	// }

	#ifdef LOCAL_OPERATOR
	vec3 ILocal = vec3(Luminance(blur));
		 ILocal -= pow(Luminance(bloomData.blur2), 4.1f) * 100000000000.0f;
		 ILocal = max(vec3(0.000000000001f), ILocal);

		 //ILocal = vec3(sMax * 2.25f);
	#endif



	#ifdef LOCAL_OPERATOR
	vec3 IGlobal = vec3(averageLuminance);
	vec3 IAverage = mix(ILocal, IGlobal, vec3(adaptation));
	#else
	vec3 IAverage = vec3(averageLuminance);
	#endif

	vec3 value = color.rgb / (color.rgb + IAverage);




	#ifdef TONEMAP_NATURAL
	color.rgb = value * 2.195f - 0.00f;
	color.rgb = pow(color.rgb, vec3(0.99f));
	#endif

	#ifdef TONEMAP_FILMIC
	color.rgb = value * 1.00f;
	#endif


	color.rgb = min(color.rgb, vec3(1.0f));
	// color.rgb = pow(color.rgb, vec3(0.9));


	// vec3 scolor = color * color * (3.0f - 2.0f * color);
	//  //scolor = color * color * (3.0f - 2.0f * color);

	// color.rgb = mix(color.rgb, scolor.rgb, vec3(1.0f));

	// color.rgb = pow(color.rgb, vec3(0.6));

	// float colorM = max(max(color.r, color.g), color.b);
	// vec3 colorN = color.rgb / colorM;
	// color.rgb = colorN * pow(colorM, 0.8f);


	color.rgb = pow(color.rgb, vec3(1.0f / 2.2f));
	//color.rgb -= vec3(0.025f);
}

void LowlightFuzziness(inout vec3 color, in BloomDataStruct bloomData)
{
	float lum = Luminance(color.rgb);
	float factor = 1.0f - clamp(lum * 50000000.0f, 0.0f, 1.0f);
	      //factor *= factor * factor;


	float time = frameTimeCounter * 4.0f;
	vec2 coord = texture2D(noisetex, vec2(time, time / 64.0f)).xy;
	vec3 snow = BicubicTexture(noisetex, (texcoord.st + coord) / (512.0f / vec2(viewWidth, viewHeight))).rgb;	//visual snow
	vec3 snow2 = BicubicTexture(noisetex, (texcoord.st + coord) / (128.0f / vec2(viewWidth, viewHeight))).rgb;	//visual snow

	vec3 rodColor = vec3(0.2f, 0.4f, 1.0f) * 2.5;
	vec3 rodLight = dot(color.rgb + snow.r * 0.0000000005f, vec3(0.0f, 0.6f, 0.4f)) * rodColor;
	color.rgb = mix(color.rgb, rodLight, vec3(factor));	//visual acuity loss

	color.rgb += snow.rgb * snow2.rgb * snow.rgb * 0.000000002f;


}


/////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void main() {

	vec3 color = GetColorTexture(texcoord.st);	//Sample gcolor texture

	mask.matIDs = GetMaterialIDs(texcoord.st);
	CalculateMasks(mask);

	//color /= mix(1.0f, 2.0f, float(mask.sky));
	color /= mix(1.0f, 10.0f, float(mask.glowstone));

	//MotionBlur(color);

	//DepthOfField(color);



	CalculateBloom(bloomData);			//Gather bloom textures
	color = mix(color, bloomData.bloom, vec3(0.0150f));

	AddRainFogScatter(color, bloomData);

	//vec3 highpass = (GetColorTexture(texcoord.st).rgb - bloomData.blur0);

	//color += bloomData.blur5;

	//LowlightFuzziness(color, bloomData);


	Vignette(color);

	CalculateExposure(color);

	//TonemapVorontsov(color);
	//TonemapReinhard(color);
	//TonemapReinhardLum(color);
	//TonemapReinhard07(color, bloomData);
	TonemapReinhard05(color, bloomData);


	//if (texture2D(composite, texcoord.st).g > 0.01f)
	//	color.g = 1.0f;

	//TonemapReinhardLinearHybrid(color);
	//SphericalTonemap(color);
	//SaturationBoost(color);
	//SaturationBoost(color);

	//color.rgb += highpass * 10000.0f;
	//LowtoneSaturate(color);

	//ColorGrading(color);

	//color.rgb = texture2DLod(gcolor, texcoord.st, 2).rgb * 10.0f;
	//color.rgb = vec3(texture2DLod(shadowtex1, texcoord.st, 3).x) * 1.0f;

	//color.rgb = vec3(fwidth(GetDepthLinear(texcoord.st + vec2(0.5 / viewWidth, 0.5 / viewHeight)) + GetDepthLinear(texcoord.st - vec2(0.5 / viewWidth, 0.5 / viewHeight))));

	// color.rgb += fwidth(color.rgb) * 0.5;

	gl_FragColor = vec4(color.rgb, 1.0f);

}
