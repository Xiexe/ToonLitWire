Shader "Xiexe/ToonLitWire" {
    Properties {
		[Enum(Line,0,Point,1,Triangle,2)] _RenderType ("Render Mode", Int) = 0

       	_MainTex ("Main Texture", 2D) = "gray" {}
		_ShadowRamp("Shadow Ramp", 2D) = "white" {}
		_cutoff("Alpha Cutoff", Float) = 0.7
    }
    SubShader {
		
			Pass{ Name "FORWARD" 
				  Tags{"LightMode" = "ForwardBase" 
					   "RenderType"="Transparent" 
				 	   "Queue"="AlphaTest"}
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma geometry geom
			#define UNITY_PASS_FORWARDBASE
			#pragma multi_compile_fwdbase_fullshadows
			#pragma only_renderers d3d11 glcore gles
			#pragma target 4.0
			#include "AutoLight.cginc"
			#include "Lighting.cginc"
			#pragma shader_feature _ _TRIANGLE_ON _LINE_ON _POINT_ON
			
		 	sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _ShadowRamp;
			float _cutoff;

			struct VertexInput {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float2 uv0 : TEXCOORD0;
				float2 uv1 : TEXCOORD1;
				float4 worldPos : TEXCOORD3;
				SHADOW_COORDS(2)
			};

			struct VertexOutput {
				float4 pos : SV_POSITION;
				float3 normal : NORMAL;
				float2 uv0 : TEXCOORD0;
				float2 uv1 : TEXCOORD1;
				float4 worldPos : TEXCOORD2;
				SHADOW_COORDS(3)
			};

			struct g2f
			{
				float4 pos : SV_POSITION;
				float2 uv0 : TEXCOORD0;
				float2 uv1 : TEXCOORD1;
				float3 normal : TEXCOORD2; 
				float4 worldPos : TEXCOORD3;
				SHADOW_COORDS(4)
			};

			VertexOutput vert(VertexInput v) {
				VertexOutput OUT;

				OUT.normal = mul(unity_ObjectToWorld, v.normal);
				OUT.uv0 = v.uv0;
				OUT.uv1 = v.uv1;
				OUT.pos = v.vertex;
				OUT.worldPos = mul(unity_ObjectToWorld, v.vertex);
				TRANSFER_SHADOW(OUT);
				return OUT;
			}

			[maxvertexcount(3)]
			void geom(triangle VertexInput IN[3], uint pid : SV_PrimitiveID, inout TriangleStream<g2f> tristream)
			{
				g2f o;
				//tristream.RestartStrip();
				for (int i = 0; i < 3; i++)
				{
					o.pos = UnityObjectToClipPos(IN[i].vertex);
					o.uv0 = IN[i].uv0;
					o.uv1 = IN[i].uv1;
					o.normal = IN[i].normal;
					o.worldPos = IN[i].worldPos;	
					// Pass-through the shadow coordinates if this pass has shadows.
					#if defined (SHADOWS_SCREEN) || ( defined (SHADOWS_DEPTH) && defined (SPOT) ) || defined (SHADOWS_CUBE)
					o._ShadowCoord = IN[i]._ShadowCoord;
					#endif
					tristream.Append(o);
				}
			}

			float3 CustomLightingFunction(float3 normal, float3 worldPos, sampler2D RampTex, struct g2f i)
			{
				//do attenuation and normals
			//	#if defined(SHADOWS_SCREEN)
			//		float atten = 1;
			//	#else
			//		UNITY_LIGHT_ATTENUATION(attenuation, i, worldPos);
			//	#endif


				float3 worldNormal = normalize(normal);
				float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
				float nDotl = DotClamped(lightDir, worldNormal);
			
				half3 shadeSH9Light = ShadeSH9(float4(worldNormal,1));
				half3 reverseShadeSH9Light = ShadeSH9(float4(-worldNormal,1));
				half3 noAmbientShadeSH9Light = (shadeSH9Light - reverseShadeSH9Light)/2;
				
				float3 indirectLight = noAmbientShadeSH9Light * 0.5 + 0.533;
				float3 lightintensity = ShadeSH9(float4(0,0,0,1));

				float light_Env = float(any(_WorldSpaceLightPos0.xyz));

				float2 rampUV = lerp(indirectLight, nDotl, light_Env);		
				float3 shadowRamp = tex2D(RampTex, float2(rampUV.x, rampUV.y));
				
				float3 lightCol = _LightColor0 * (shadowRamp);
				float3 lighting = lightCol + (shadowRamp) * lightintensity;
				
				return lighting;// * attenuation;
			}

			float4 frag(g2f i) : COLOR{

				float3 finalLight = CustomLightingFunction(i.normal, i.worldPos, _ShadowRamp, i);
				float4 mainTex = tex2D(_MainTex, i.uv0);
				float3 col = mainTex * finalLight;	
				clip(mainTex.a  - _cutoff);

				return fixed4(col, 1);
			}
				ENDCG
			}
    }
    FallBack "Diffuse"
}