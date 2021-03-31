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

/////////ADJUSTABLE VARIABLES//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////ADJUSTABLE VARIABLES//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#define SHADOW_MAP_BIAS 0.80

#define ENABLE_SOFT_SHADOWS






/////////INTERNAL VARIABLES////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////INTERNAL VARIABLES////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//Do not change the name of these variables or their type. The Shaders Mod reads these lines and determines values to send to the inner-workings
//of the shaders mod. The shaders mod only reads these lines and doesn't actually know the real value assigned to these variables in GLSL.
//Some of these variables are critical for proper operation. Change at your own risk.

const int 		shadowMapResolution 	= 8192;
const float 	shadowDistance 			= 350.0;
const float 	shadowIntervalSize 		= 0.001;
const bool 		shadowHardwareFiltering0 = true;

const bool 		shadowtex1Mipmap = true;
const bool 		shadowtex1Nearest = true;
const bool 		shadowcolor0Mipmap = true;
const bool 		shadowcolor0Nearest = false;
const bool 		shadowcolor1Mipmap = true;
const bool 		shadowcolor1Nearest = false;

const int 		R8 						= 0;
const int 		RG8 					= 0;
const int 		RGB8 					= 1;
const int 		RGB16 					= 2;
const int 		gcolorFormat 			= RGB16;
const int 		gdepthFormat 			= RGB8;
const int 		gnormalFormat 			= RGB16;
const int 		compositeFormat 		= RGB8;

const float 	eyeBrightnessHalflife 	= 10.0f;
const float 	centerDepthHalflife 	= 2.0f;
const float 	wetnessHalflife 		= 100.0f;
const float 	drynessHalflife 		= 40.0f;

const int 		superSamplingLevel 		= 0;

const float		sunPathRotation 		= -40.0f;
const float 	ambientOcclusionLevel 	= 0.5f;

const int 		noiseTextureResolution  = 64;


//END OF INTERNAL VARIABLES//

/* DRAWBUFFERS:45 */

uniform sampler2D gnormal;
uniform sampler2D gdepthtex;
uniform sampler2D gdepth;
uniform sampler2D shadowcolor1;
uniform sampler2D shadowcolor;
uniform sampler2D shadowtex1;
uniform sampler2D noisetex;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferProjection;

varying vec4 texcoord;
varying vec3 lightVector;

varying float timeSunriseSunset;
varying float timeNoon;
varying float timeMidnight;
varying float timeSkyDark;

varying vec3 colorSunlight;
varying vec3 colorSkylight;
varying vec3 colorSunglow;
varying vec3 colorBouncedSunlight;
varying vec3 colorScatteredSunlight;
varying vec3 colorTorchlight;
varying vec3 colorWaterMurk;
varying vec3 colorWaterBlue;
varying vec3 colorSkyTint;
																																																																																																																									#define K1J5 )
uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform float wetness;
uniform float aspectRatio;
uniform float frameTimeCounter;
uniform float sunAngle;
uniform vec3 skyColor;
uniform vec3 cameraPosition;

/////////////////////////FUNCTIONS/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////FUNCTIONS/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
																																																																																																																														#define RW32 vec3
vec3  	GetNormals(in vec2 coord) {				//Function that retrieves the screen space surface normals. Used for lighting calculations
	return texture2DLod(gnormal, coord.st, 0).rgb * 2.0f - 1.0f;
}

float 	GetDepth(in vec2 coord) {
	return texture2D(gdepthtex, coord.st).x;
}

vec4  	GetScreenSpacePosition(in vec2 coord) {	//Function that calculates the screen-space position of the objects in the scene using the depth texture and the texture coordinates of the full-screen quad
	float depth = GetDepth(coord);
	vec4 fragposition = gbufferProjectionInverse * vec4(coord.s * 2.0f - 1.0f, coord.t * 2.0f - 1.0f, 2.0f * depth - 1.0f, 1.0f);
		 fragposition /= fragposition.w;
																																																																																																																																	#define UBWG texture2DLod
	return fragposition;
}

vec3 	CalculateNoisePattern1(vec2 offset, float size) {
	vec2 coord = texcoord.st;
																																																																																																																																																									#define U73B shadowcolor1
	coord *= vec2(viewWidth, viewHeight);
	coord = mod(coord + offset, vec2(size));
	coord /= noiseTextureResolution;
																																																																																																																		#define U38J (
	return texture2D(noisetex, coord).xyz;
}

vec2 DistortShadowSpace(in vec2 pos)
{
	vec2 signedPos = pos * 2.0f - 1.0f;

	float dist = sqrt(signedPos.x * signedPos.x + signedPos.y * signedPos.y);
	float distortFactor = (1.0f - SHADOW_MAP_BIAS) + dist * SHADOW_MAP_BIAS;
	signedPos.xy /= distortFactor;
																																																																																																																															#define I636 float
	pos = signedPos * 0.5f + 0.5f;
																																																																																																																																																																																	#define U008 shadowtex1
	return pos;
}

vec3 Contrast(in vec3 color, in float contrast)
{
	float colorLength = length(color);
	vec3 nColor = color / colorLength;
																																																																																																	#define IP89 if
	colorLength = pow(colorLength, contrast);
																																																																																																																																																																														#define JJ8B shadowcolor
	return nColor * colorLength;
}

float 	GetMaterialIDs(in vec2 coord) {			//Function that retrieves the texture that has all material IDs stored in it
	return texture2D(gdepth, coord).r;
}

bool 	GetSkyMask(in vec2 coord)
{
	float matID = GetMaterialIDs(coord);
	matID = floor(matID * 255.0f);
																																																																																																																	#define OIU3 int
	if (matID < 1.0f || matID > 254.0f)
	{
		return true;
	} else {
		return false;
	}
}

float GetAO(in vec4 screenSpacePosition, in vec3 normal, in vec2 coord, in vec3 dither)
{
	//Determine origin position
	vec3 origin = screenSpacePosition.xyz;

	vec3 randomRotation = normalize(dither.xyz * vec3(2.0f, 2.0f, 1.0f) - vec3(1.0f, 1.0f, 0.0f));

	vec3 tangent = normalize(randomRotation - normal * dot(randomRotation, normal));
	vec3 bitangent = cross(normal, tangent);
	mat3 tbn = mat3(tangent, bitangent, normal);

	float aoRadius   = 0.25f * -screenSpacePosition.z;
		  //aoRadius   = 0.8f;
	float zThickness = 0.25f * -screenSpacePosition.z;
		  //zThickness = 2.2f;

	vec3 	samplePosition 		= vec3(0.0f);
	float 	intersect 			= 0.0f;
	vec4 	sampleScreenSpace 	= vec4(0.0f);
	float 	sampleDepth 		= 0.0f;
	float 	distanceWeight 		= 0.0f;
	float 	finalRadius 		= 0.0f;

	int numRaysPassed = 0;

	float ao = 0.0f;

	for (int i = 0; i < 4; i++)
	{
		vec3 kernel = vec3(texture2D(noisetex, vec2(0.1f + (i * 1.0f) / 64.0f)).r * 2.0f - 1.0f,
					     texture2D(noisetex, vec2(0.1f + (i * 1.0f) / 64.0f)).g * 2.0f - 1.0f,
					     texture2D(noisetex, vec2(0.1f + (i * 1.0f) / 64.0f)).b * 1.0f);
			 kernel = normalize(kernel);
			 kernel *= pow(dither.x + 0.01f, 1.0f);

		samplePosition = tbn * kernel;
		samplePosition = samplePosition * aoRadius + origin;

			sampleScreenSpace = gbufferProjection * vec4(samplePosition, 0.0f);
			sampleScreenSpace.xyz /= sampleScreenSpace.w;
			sampleScreenSpace.xyz = sampleScreenSpace.xyz * 0.5f + 0.5f;

			//Check depth at sample point
			sampleDepth = GetScreenSpacePosition(sampleScreenSpace.xy).z;

			//If point is behind geometry, buildup AO
			if (sampleDepth >= samplePosition.z && sampleDepth - samplePosition.z < zThickness)
			{
				ao += 1.0f;
			} else {

			}
	}
	ao /= 4;
	ao = 1.0f - ao;
	ao = pow(ao, 1.0f);

	return ao;
}













vec4 f U38J in  OIU3  f,in vec2 d,in  I636  v,in  I636  z, RW32  s K1J5 { I636  x=pow U38J 2.f, I636  U38J f K1J5  K1J5 ,y=.002f; IP89  U38J texcoord.x-d.x+y<1.f/x+y*2.f&&texcoord.y-d.y+y<1.f/x+y*2.f&&texcoord.x-d.x+y>0.f&&texcoord.y-d.y+y>0.f K1J5 {vec2 i= U38J texcoord.xy-d.xy K1J5 *x; RW32  t=GetNormals U38J i.xy K1J5 ;vec4 m=gbufferModelViewInverse*vec4 U38J t.xyz,0.f K1J5 ;m=shadowModelView*m;m.xyz=normalize U38J m.xyz K1J5 ; RW32  a=m.xyz;vec4 S=GetScreenSpacePosition U38J i.xy K1J5 ; RW32  r=normalize U38J S.xyz K1J5 ; I636  e=sqrt U38J S.x*S.x+S.y*S.y+S.z*S.z K1J5 ,p=texture2D U38J gdepth,i K1J5 .x*255.f;vec4 o=shadowModelView*vec4 U38J 0.f,1.,0.,0. K1J5 ,n=gbufferModelViewInverse*S;n=shadowModelView*n; I636  c=-n.z;n=shadowProjection*n;n/=n.w; I636  w=sqrt U38J n.x*n.x+n.y*n.y K1J5 ,l=1.f-SHADOW_MAP_BIAS+w*SHADOW_MAP_BIAS;n=n*.5f+.5f; I636  b=0.f,h=0.f; RW32  g= RW32  U38J 0.f K1J5 ; I636  D=0.; IP89  U38J e<shadowDistance&&c>0.f&&n.x<1.f&&n.x>0.f&&n.y<1.f&&n.y>0.f K1J5 { I636  M=.15f;b=clamp U38J shadowDistance*.85f*M-e*M,0.f,1.f K1J5 ; I636  u=v; OIU3  G=0; I636  A=2.f*u/2048;vec2 V=s.xy-.5f; I636  P=1.f/z;for U38J  I636  I=-2.f;I<=2.f;I+=P K1J5 {for U38J  I636  O=-2.f;O<=2.f;O+=P K1J5 {vec2 L= U38J vec2 U38J I,O K1J5 +V*P K1J5 *A,W=n.xy+L,H=DistortShadowSpace U38J W K1J5 ; I636  B= UBWG  U38J  U008 ,H,2 K1J5 .x; RW32  q= RW32  U38J W.x,W.y,B K1J5 ,k=normalize U38J q.xyz-n.xyz K1J5 ,N= UBWG  U38J  U73B ,H,5 K1J5 .xyz*2.f-1.f;N.x=-N.x;N.y=-N.y; I636  j=max U38J 0.f,dot U38J a.xyz,k* RW32  U38J 1.,1.,-1. K1J5  K1J5  K1J5 ; IP89  U38J abs U38J p-3.f K1J5 <.1f||abs U38J p-2.f K1J5 <.1f||abs U38J p-11.f K1J5 <.1f K1J5 j=1.f; IP89  U38J j>0. K1J5 {bool Z=length U38J N K1J5 <.5f; IP89  U38J Z K1J5 N.xyz= RW32  U38J 0.f,0.f,1.f K1J5 ; I636  Y=dot U38J k,N K1J5 ,X=Y; IP89  U38J Z K1J5 Y=abs U38J Y K1J5 *.25f;Y=max U38J Y,0.f K1J5 ; I636  U=length U38J q.xyz-n.xyz- RW32  U38J 0.f,0.f,0.f K1J5  K1J5 ; IP89  U38J U<.005f K1J5 U=1e+07f;const  I636  T=2.f; I636  R=1.f/ U38J pow U38J U* U38J 13600.f/u K1J5 ,T K1J5 +.0001f*P K1J5 ;R=max U38J 0.f,R-9e-05f K1J5 ; IP89  U38J X<0.f K1J5 R=max U38J R*30.f-.13f,0.f K1J5 ,R*=.04f; RW32  Q=pow U38J  UBWG  U38J  JJ8B ,H,5 K1J5 .xyz, RW32  U38J 2.2f K1J5  K1J5 ;g+=Q*Y*R*j;}G+=1;}}g/=G;}g=mix U38J  RW32  U38J 0.f K1J5 ,g, RW32  U38J b K1J5  K1J5 ; I636  R=1.f;bool P=GetSkyMask U38J i.xy K1J5 ; IP89  U38J !P K1J5 R*=GetAO U38J S.xyzw,t.xyz,i.xy,s.xyz K1J5 ;return vec4 U38J g.xyz*1150.f,R K1J5 ;}else return vec4 U38J 0.f K1J5 ;}


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

float  	CalculateDitherPattern1() {
	const int[16] ditherPattern = int[16] (0 , 8 , 2 , 10,
									 	   12, 4 , 14, 6 ,
									 	   3 , 11, 1,  9 ,
									 	   15, 7 , 13, 5 );

	vec2 count = vec2(0.0f);
	     count.x = floor(mod(texcoord.s * viewWidth, 4.0f));
		 count.y = floor(mod(texcoord.t * viewHeight, 4.0f));

	int dither = ditherPattern[int(count.x) + int(count.y) * 4];

	return float(dither) / 16.0f;
}

void 	DoNightEye(inout vec3 color) {			//Desaturates any color input at night, simulating the rods in the human eye

	float amount = 0.8f; 						//How much will the new desaturated and tinted image be mixed with the original image
	vec3 rodColor = vec3(0.2f, 0.4f, 1.0f); 	//Cyan color that humans percieve when viewing extremely low light levels via rod cells in the eye
	float colorDesat = dot(color, vec3(1.0f)); 	//Desaturated color

	color = mix(color, vec3(colorDesat) * rodColor, timeMidnight * amount);
	//color.rgb = color.rgb;
}


float   CalculateSunglow(vec4 screenSpacePosition, vec3 lightVector) {

	float curve = 4.0f;

	vec3 npos = normalize(screenSpacePosition.xyz);
	vec3 halfVector2 = normalize(-lightVector + npos);
	float factor = 1.0f - dot(halfVector2, npos);

	return factor * factor * factor * factor;
}

float Get3DNoise(in vec3 pos)
{
	pos.z += 0.0f;

	pos.xyz += 0.5f;

	vec3 p = floor(pos);
	vec3 f = fract(pos);

	// f.x = f.x * f.x * (3.0f - 2.0f * f.x);
	// f.y = f.y * f.y * (3.0f - 2.0f * f.y);
	// f.z = f.z * f.z * (3.0f - 2.0f * f.z);

	vec2 uv =  (p.xy + p.z * vec2(17.0f)) + f.xy;
	vec2 uv2 = (p.xy + (p.z + 1.0f) * vec2(17.0f)) + f.xy;

	// uv -= 0.5f;
	// uv2 -= 0.5f;

	vec2 coord =  (uv  + 0.5f) / noiseTextureResolution;
	vec2 coord2 = (uv2 + 0.5f) / noiseTextureResolution;
	float xy1 = texture2D(noisetex, coord).x;
	float xy2 = texture2D(noisetex, coord2).x;
	return mix(xy1, xy2, f.z);
}

float GetCoverage(in float coverage, in float density, in float clouds)
{
	clouds = clamp(clouds - (1.0f - coverage), 0.0f, 1.0f -density) / (1.0f - density);
		clouds = max(0.0f, clouds * 1.1f - 0.1f);
	 clouds = clouds = clouds * clouds * (3.0f - 2.0f * clouds);
	 // clouds = pow(clouds, 1.0f);
	return clouds;
}

vec4 CloudColor(in vec4 worldPosition, in float sunglow, in vec3 worldLightVector)
{

	float cloudHeight = 1250f;
	float cloudDepth  = 190.0f;
	float cloudUpperHeight = cloudHeight + (cloudDepth / 2.0f);
	float cloudLowerHeight = cloudHeight - (cloudDepth / 2.0f);

	if (worldPosition.y < cloudLowerHeight || worldPosition.y > cloudUpperHeight)
		return vec4(0.0f);
	else
	{

		vec3 p = worldPosition.xyz / 150.0f;



		float t = frameTimeCounter * 5.0f;
			  //t *= 0.001;
		p.x -= t * 0.02f;

		// p += (Get3DNoise(p * 1.0f + vec3(0.0f, t * 0.01f, 0.0f)) * 2.0f - 1.0f) * 0.15f;

		vec3 p1 = p * vec3(1.0f, 0.5f, 1.0f)  + vec3(0.0f, t * 0.01f, 0.0f);
		float noise  = 	Get3DNoise(p * vec3(1.0f, 0.5f, 1.0f) + vec3(0.0f, t * 0.01f, 0.0f));	p *= 2.0f;	p.x -= t * 0.097f;	vec3 p2 = p;
			  noise += (1.0 - abs(Get3DNoise(p) * 1.0f - 0.5f) - 0.1) * 0.55f;					p *= 2.5f;	p.xz -= t * 0.065f;	vec3 p3 = p;
			  noise += (1.0 - abs(Get3DNoise(p) * 3.0f - 1.5f) - 0.2) * 0.065f;					p *= 2.5f;	p.xz -= t * 0.165f;	vec3 p4 = p;
			  noise += (1.0 - abs(Get3DNoise(p) * 3.0f - 1.5f)) * 0.032f;						p *= 2.5f;	p.xz -= t * 0.165f;
			  noise += (1.0 - abs(Get3DNoise(p) * 2.0 - 1.0)) * 0.015f;												p *= 2.5f;
			  // noise += (1.0 - abs(Get3DNoise(p) * 2.0 - 1.0)) * 0.016f;
			  noise /= 1.875f;



		const float lightOffset = 0.3f;


		float heightGradient = clamp(( - (cloudLowerHeight - worldPosition.y) / (cloudDepth * 1.0f)), 0.0f, 1.0f);
		float heightGradient2 = clamp(( - (cloudLowerHeight - (worldPosition.y + worldLightVector.y * lightOffset * 150.0f)) / (cloudDepth * 1.0f)), 0.0f, 1.0f);

		float cloudAltitudeWeight = 1.0f - clamp(distance(worldPosition.y, cloudHeight) / (cloudDepth / 2.0f), 0.0f, 1.0f);
			  cloudAltitudeWeight = (-cos(cloudAltitudeWeight * 3.1415f)) * 0.5 + 0.5;
			  cloudAltitudeWeight = pow(cloudAltitudeWeight, mix(0.33f, 0.8f, rainStrength));
			  //cloudAltitudeWeight *= 1.0f - heightGradient;
			  //cloudAltitudeWeight = 1.0f;

		float cloudAltitudeWeight2 = 1.0f - clamp(distance(worldPosition.y + worldLightVector.y * lightOffset * 150.0f, cloudHeight) / (cloudDepth / 2.0f), 0.0f, 1.0f);
			  cloudAltitudeWeight2 = (-cos(cloudAltitudeWeight2 * 3.1415f)) * 0.5 + 0.5;
			  cloudAltitudeWeight2 = pow(cloudAltitudeWeight2, mix(0.33f, 0.8f, rainStrength));
			  //cloudAltitudeWeight2 *= 1.0f - heightGradient2;
			  //cloudAltitudeWeight2 = 1.0f;

		noise *= cloudAltitudeWeight;

		//cloud edge
		float coverage = 0.45f;
			  coverage = mix(coverage, 0.77f, rainStrength);

			  float dist = length(worldPosition.xz - cameraPosition.xz);
			  coverage *= max(0.0f, 1.0f - dist / 40000.0f);
		float density = 0.87f;
		noise = GetCoverage(coverage, density, noise);
		noise = pow(noise, 1.5);


		if (noise <= 0.001f)
		{
			return vec4(0.0f, 0.0f, 0.0f, 0.0f);
		}

		//float sunProximity = pow(sunglow, 1.0f);
		//float propigation = mix(15.0f, 9.0f, sunProximity);


		// float directLightFalloff = pow(heightGradient, propigation);
		// 	  directLightFalloff += pow(heightGradient, propigation / 2.0f);
		// 	  directLightFalloff /= 2.0f;






	float sundiff = Get3DNoise(p1 + worldLightVector.xyz * lightOffset);
		  sundiff += (1.0 - abs(Get3DNoise(p2 + worldLightVector.xyz * lightOffset / 2.0f) * 1.0f - 0.5f) - 0.1) * 0.55f;
		  // sundiff += (1.0 - abs(Get3DNoise(p3 + worldLightVector.xyz * lightOffset / 5.0f) * 3.0f - 1.5f) - 0.2) * 0.085f;
		  // sundiff += (1.0 - abs(Get3DNoise(p4 + worldLightVector.xyz * lightOffset / 8.0f) * 3.0f - 1.5f)) * 0.052f;
		  sundiff *= 0.955f;
		  sundiff *= cloudAltitudeWeight2;
	float preCoverage = sundiff;
		  sundiff = -GetCoverage(coverage * 1.0f, density * 0.5, sundiff);
	float sundiff2 = -GetCoverage(coverage * 1.0f, 0.0, preCoverage);
	float firstOrder 	= pow(clamp(sundiff * 1.2f + 1.7f, 0.0f, 1.0f), 8.0f);
	float secondOrder 	= pow(clamp(sundiff2 * 1.2f + 1.1f, 0.0f, 1.0f), 4.0f);



	float anisoBackFactor = mix(clamp(pow(noise, 2.0f) * 1.0f, 0.0f, 1.0f), 1.0f, pow(sunglow, 1.0f));
		  firstOrder *= anisoBackFactor * 0.99 + 0.01;
		  secondOrder *= anisoBackFactor * 0.8 + 0.2;
	float directLightFalloff = mix(firstOrder, secondOrder, 0.2f);
	// float directLightFalloff = max(firstOrder, secondOrder);

		  // directLightFalloff *= anisoBackFactor;
	 	  // directLightFalloff *= mix(11.5f, 1.0f, pow(sunglow, 0.5f));



	vec3 colorDirect = colorSunlight * 2.515f;
		 // colorDirect = mix(colorDirect, colorDirect * vec3(0.2f, 0.5f, 1.0f), timeMidnight);
		 DoNightEye(colorDirect);
		 colorDirect *= 1.0f + pow(sunglow, 4.0f) * 2400.0f * pow(firstOrder, 1.1f) * (1.0f - rainStrength);


	vec3 colorAmbient = colorSkylight * 0.065f;
		 colorAmbient *= mix(1.0f, 0.3f, timeMidnight);
		 colorAmbient = mix(colorAmbient, colorAmbient * 2.0f + colorSunlight * 0.05f, vec3(clamp(pow(1.0f - noise, 2.0f) * 1.0f, 0.0f, 1.0f)));
		 colorAmbient *= heightGradient * heightGradient + 0.05f;

	 vec3 colorBounced = colorBouncedSunlight * 0.35f;
	 	 colorBounced *= pow((1.0f - heightGradient), 8.0f);
	 	 colorBounced *= anisoBackFactor + 0.5;
	 	 colorBounced *= 1.0 - rainStrength;


		directLightFalloff *= 1.0f - rainStrength * 0.6f;

		// //cloud shadows
		// vec4 shadowPosition = shadowModelView * (worldPosition - vec4(cameraPosition, 0.0f));
		// shadowPosition = shadowProjection * shadowPosition;
		// shadowPosition /= shadowPosition.w;

		// float shadowdist = sqrt(shadowPosition.x * shadowPosition.x + shadowPosition.y * shadowPosition.y);
		// float distortFactor = (1.0f - SHADOW_MAP_BIAS) + shadowdist * SHADOW_MAP_BIAS;
		// shadowPosition.xy *= 1.0f / distortFactor;
		// shadowPosition = shadowPosition * 0.5f + 0.5f;

		// float sunlightVisibility = shadow2DLod(shadow, vec3(shadowPosition.st, shadowPosition.z), 4).x;
		// directLightFalloff *= sunlightVisibility;

		vec3 color = mix(colorAmbient, colorDirect, vec3(min(1.0f, directLightFalloff)));
			 color += colorBounced;
		     // color = colorAmbient;
		     //color = colorDirect * directLightFalloff;
			 //color *= clamp(pow(noise, 0.1f), 0.0f, 1.0f);

		color *= 1.0f;

		//color *= mix(1.0f, 0.4f, timeMidnight);

		vec4 result = vec4(color.rgb, noise);

		return result;
	}
}

void 	CalculateClouds2 (inout vec4 color, vec4 screenSpacePosition, vec4 worldSpacePosition, vec3 worldLightVector)
{
	if (texcoord.s < 0.25f && texcoord.t < 0.25f)
	{
		// surface.cloudAlpha = 0.0f;
		vec2 coord = texcoord.st * 4.0f;


		vec4 screenPosition = GetScreenSpacePosition(coord);

		bool isSky = GetSkyMask(coord);

		float sunglow = CalculateSunglow(screenPosition, lightVector);

		vec4 worldPosition = gbufferModelViewInverse * GetScreenSpacePosition(coord);
			 worldPosition.xyz += cameraPosition.xyz;

		float cloudHeight = 220.0f;
		float cloudDepth  = 140.0f;
		float cloudDensity = 1.0f;

		float startingRayDepth = far - 5.0f;

		float rayDepth = startingRayDepth;
			  //rayDepth += CalculateDitherPattern1() * 0.85f;
			  //rayDepth += texture2D(noisetex, texcoord.st * (viewWidth / noiseTextureResolution, viewHeight / noiseTextureResolution)).x * 0.1f;
			  //rayDepth += CalculateDitherPattern2() * 0.1f;
		float rayIncrement = far / 10.0f;

			  //rayDepth += CalculateDitherPattern1() * rayIncrement;

		// float dither = CalculateDitherPattern1();

		int i = 0;

		vec3 cloudColor = colorSunlight;
		vec4 cloudSum = vec4(0.0f);
			 cloudSum.rgb = colorSkylight * 0.2f;
			 cloudSum.rgb = color.rgb;


		float cloudDistanceMult = 800.0f / far;


		float surfaceDistance = length(worldPosition.xyz - cameraPosition.xyz);

		vec4 toEye = gbufferModelView * vec4(0.0f, 0.0f, -1.0f, 0.0f);

		vec4 startPosition = GetCloudSpacePosition(coord, rayDepth, cloudDistanceMult);

		const int numSteps = 800;
		const float numStepsF = 800.0f;

		// while (rayDepth > 0.0f)
		for (int i = 0; i < numSteps; i++)
		{
			//determine worldspace ray position
			// vec4 rayPosition = GetCloudSpacePosition(texcoord.st, rayDepth, cloudDistanceMult);
			float inormalized = i / numStepsF;
				  // inormalized += dither / numStepsF;
				  // inormalized = pow(inormalized, 0.5);
			vec4 rayPosition = vec4(0.0);
			     rayPosition.xyz = mix(startPosition.xyz, cameraPosition.xyz, inormalized);

			float rayDistance = length((rayPosition.xyz - cameraPosition.xyz) / cloudDistanceMult);

			// if (surfaceDistance < rayDistance * cloudDistanceMult && isSky)
			// {
			// 	continue; TODO re-enable
			// }

			vec4 proximity =  CloudColor(rayPosition, sunglow, worldLightVector);
				 proximity.a *= cloudDensity;

				 //proximity.a *=  clamp(surfaceDistance - rayDistance, 0.0f, 1.0f);
				 // if (surfaceDistance < rayDistance * cloudDistanceMult && surface.mask.sky < 0.5f)
				 // 	proximity.a = 0.0f;

				 if (!isSky)
				 proximity.a *= clamp((surfaceDistance - (rayDistance * cloudDistanceMult)) / rayIncrement, 0.0f, 1.0f);

			//cloudSum.rgb = mix( cloudSum.rgb, proximity.rgb, vec3(min(1.0f, proximity.a * cloudDensity)) );
			//cloudSum.a += proximity.a * cloudDensity;
			color.rgb = mix(color.rgb, proximity.rgb, vec3(min(1.0f, proximity.a * cloudDensity)));

			color.a += proximity.a;

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
}


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void main() {

	vec3 noisePattern = CalculateNoisePattern1(vec2(0.0f), 4);
	vec4 screenSpacePosition = GetScreenSpacePosition(texcoord.st);
	vec4 worldSpacePosition = gbufferModelViewInverse * screenSpacePosition;
	vec4 worldLightVector = shadowModelViewInverse * vec4(0.0f, 0.0f, 1.0f, 0.0f);
	vec3 normal = GetNormals(texcoord.st);

	vec4 light = vec4(0.0);
		 light = f(1, 		vec2(0.0f			), 16.0f,  2.0f, noisePattern);
	//light += GetLight(0, vec2(0.0f), 2.0f, 0.5f);

	if (light.r >= 1.0f)
	{
		light.r = 0.0f;
	}

	if (light.g >= 1.0f)
	{
		light.g = 0.0f;
	}

	if (light.b >= 1.0f)
	{
		light.b = 0.0f;
	}








	vec4 clouds = vec4(0.0);
	clouds.rgb = colorSkylight * 0.03;
	// CalculateClouds2(clouds, screenSpacePosition, worldSpacePosition, worldLightVector.xyz);
	clouds.rgb = pow(clouds.rgb, vec3(1.0 / 2.2));

	gl_FragData[0] = vec4(pow(light.rgb, vec3(1.0 / 2.2)), light.a);
	gl_FragData[1] = clouds;
}
