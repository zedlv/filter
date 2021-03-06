precision highp float;
uniform sampler2D Texture;
varying vec2 TextureCoordsVarying;

void main (void) {
   vec2 uv = TextureCoordsVarying.xy;
    float x;
    float y;
    if (uv.x<=1.0/3.0){
        x = uv.x *3.0;
    }else if (uv.x<=2.0/3.0){
        x = (uv.x - 1.0/3.0) * 3.0;
    }else{
        x= (uv.x - 2.0/3.0) * 3.0;
    }
    if (uv.y<=0.5 ){
        y = uv.y  * 2.0;
    }else{
        y = (uv.y -0.5) * 2.0;
    }

    gl_FragColor = texture2D(Texture, vec2(x,y));
    
}
