Shader "Xiexe/ToonLitWire" {
    Properties {
       	_MainTex ("Main Texture", 2D) = "gray" {}
		_ShadowRamp("Shadow Ramp", 2D) = "white" {}
		_cutoff("Alpha Cutoff", Float) = 0.7
    }
    SubShader {
        Tags {
            "RenderType"="Transparent" "Queue"="AlphaTest"
        }
		
			Pass{
				Name "FORWARD"
				Tags{
				"LightMode" = "ForwardBase"
			}
			
			Cull Off

			CGPROGRAM
			#pragma vertex vert
			#pragma geometry geom
			#pragma fragment frag
			#define UNITY_PASS_FORWARDBASE
			#pragma multi_compile_fwdbase_fullshadows
			#pragma only_renderers d3d11 glcore gles
			#pragma target 4.0
			#include "UnityStandardBRDF.cginc"
			#include "AutoLight.cginc"
			#include "Lighting.cginc"
			
		 	sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _ShadowRamp;
			float _cutoff;

			struct VertexInput {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float2 uv0 : TEXCOORD0;
				float2 uv1 : TEXCOORD1;
				float4 posWorld : TEXCOORD3;
				SHADOW_COORDS(2)
			};

			struct VertexOutput {
				float4 pos : SV_POSITION;
				float3 normal : NORMAL;
				float2 uv0 : TEXCOORD0;
				float2 uv1 : TEXCOORD1;
				float4 posWorld : TEXCOORD2;
				SHADOW_COORDS(3)
			};

			struct g2f
			{
				float4 pos : SV_POSITION;
				float2 uv0 : TEXCOORD0;
				float2 uv1 : TEXCOORD1;
				float3 normal : TEXCOORD2; 
				float4 posWorld : TEXCOORD3;
				SHADOW_COORDS(4)
			};

			VertexOutput vert(VertexInput v) {
				VertexOutput OUT;

				OUT.normal = mul(unity_ObjectToWorld, v.normal);
				OUT.uv0 = v.uv0;
				OUT.uv1 = v.uv1;
				OUT.pos = v.vertex;
				OUT.posWorld = mul(unity_ObjectToWorld, v.vertex);
				TRANSFER_SHADOW(OUT);
				return OUT;
			}

			
			[maxvertexcount(16)]
			void geom(triangle VertexInput IN[3], uint pid : SV_PrimitiveID, inout LineStream<g2f> tristream)
			{
				g2f o;
				//tristream.RestartStrip();
				for (int i = 0; i < 3; i++)
				{
					o.pos = UnityObjectToClipPos(IN[i].vertex);
					o.uv0 = IN[i].uv0;
					o.uv1 = IN[i].uv1;
					o.normal = IN[i].normal;
					o.posWorld = IN[i].posWorld;	
					// Pass-through the shadow coordinates if this pass has shadows.
					#if defined (SHADOWS_SCREEN) || ( defined (SHADOWS_DEPTH) && defined (SPOT) ) || defined (SHADOWS_CUBE)
					o._ShadowCoord = IN[i]._ShadowCoord;
					#endif
					tristream.Append(o);
				}

			}

			float4 frag(g2f i) : COLOR{
				//do attenuation and normals
				//UNITY_LIGHT_ATTENUATION(atten, i, i.posWorld.xyz);
				//float3 atten = LIGHT_ATTENUATION(i);
				float3 worldNormal = normalize(i.normal);
				
				//dot products
				float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
				float nDotl = DotClamped(lightDir, worldNormal);
			
                //lighting
				float3 indirectLight = ShadeSH9(float4(worldNormal,1));
				float3 lightintensity = ShadeSH9(float4(0,0,0,1));

				float light_Env = float(any(_WorldSpaceLightPos0.xyz));

				float2 modifiedUV = lerp(indirectLight, nDotl, light_Env) * 0.5 + 0.5;

				float2 rampUV = float2(modifiedUV.x, modifiedUV.y);
				float3 shadowRamp = tex2D(_ShadowRamp, (rampUV));
				
				float3 lightCol = _LightColor0 * (shadowRamp);
				float3 lighting = lightCol + (shadowRamp) * lightintensity;

				float4 mainTex = tex2D(_MainTex, i.uv0);
				float3 finalColor = mainTex * lighting ;
				clip(mainTex.a  - _cutoff);
				return fixed4(finalColor,1);
				
			}
				ENDCG
			}
    }
    FallBack "Diffuse"
}
