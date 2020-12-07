Shader "Toon/ToonStandard"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color("Color", Color) = (1,1,1,1)
        [HDR]
        _SpecularColor("Specular Color", Color) = (0.9,0.9,0.9,1)
        [HDR]
        _AmbientColor("Ambient Color", Color) = (0.4,0.4,0.4,1)
        _Glossiness("Glossiness", Float) = 32
        _OutlineDistance("Outline Thickness", Range(0, 0.01)) = 0.005
        _LineColor("Outline Color", Color) = (1,1,1,1)
        _RimAmount("Rim Amount", Range(1, 0)) = 0.716
        _RimColor("Rim Color", Color) = (1,1,1,1)
    }
    SubShader
    {
        // alternative to vertex extrusion may be a wireframe shader like this one:
        // http://developer.download.nvidia.com/SDK/10/direct3d/Source/SolidWireframe/Doc/SolidWireframe.pdf

        Pass
        {
            Name "Outline"
            Cull Front

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
            };

            float _OutlineDistance;
            half4 _LineColor;

            v2f vert(appdata v)
            {
                v2f o;
                // does the line width stay constant with the camera distance? See: https://forum.unity.com/threads/lwrp-outline-shader-help-needed.710642/
                v.vertex.xyz += _OutlineDistance * v.normal;
                o.pos = UnityObjectToClipPos(v.vertex);

                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                fixed4 col = _LineColor;
                return col;
            }
            ENDCG
        }

        Pass
        {
            //Lighting calculations mostly done like https://roystan.net/articles/toon-shader.html
            Name "ForwardBase"
            Tags { "LightMode" = "ForwardBase"}
            LOD 100

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 pos : SV_POSITION;
                float3 worldNormal : NORMAL;
                float3 viewDir : TEXCOORD1;
                SHADOW_COORDS(2)
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            half4 _Color;
            float _Glossiness;
            half4 _SpecularColor;
            half4 _AmbientColor;
            float _RimAmount;
            half4 _RimColor;

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                TRANSFER_SHADOW(o);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.viewDir = WorldSpaceViewDir(v.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                //normal, light and half vector
                float3 normal = normalize(i.worldNormal);
                float3 viewDir = normalize(i.viewDir);
                float3 halfVector = normalize(_WorldSpaceLightPos0 + viewDir);
                float NdotL = dot(_WorldSpaceLightPos0, normal);
                float NdotH = dot(normal, halfVector);

                //light and shadow
                float shadow = SHADOW_ATTENUATION(i);
                float lightIntensity = smoothstep(0, 0.1, NdotL * shadow);
                float4 light = lightIntensity * _LightColor0;

                //specular
                float specularIntensity = pow(NdotH * lightIntensity, _Glossiness * _Glossiness);
                float specular = smoothstep(0.005, 0.01, specularIntensity) * _SpecularColor;

                //rim Lighting
                float4 rimDot = 1 - dot(viewDir, normal);
                float rimIntensity = rimDot * NdotL;
                rimIntensity = smoothstep(_RimAmount - 0.01, _RimAmount + 0.01, rimIntensity);
                float4 rim = _RimColor * rimIntensity;

                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);

                return col * _Color * (_AmbientColor + light + specular + rim);
            }
            ENDCG
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            ZWrite On
            ZTest LEqual
            Cull Off

            CGPROGRAM
            #include "UnityCG.cginc"
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compilecaster

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                V2F_SHADOW_CASTER;
                float2 uv : TEXCOORD1;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert(appdata v)
            {
                v2f o;
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                SHADOW_CASTER_FRAGMENT(i);
            }
            ENDCG
        }
    }
}
