precision highp float;
uniform sampler2D Texture;
varying vec2 TextureCoordsVarying;

void main (void) {
//    vec4 mask = texture2D(Texture, TextureCoordsVarying);
//    gl_FragColor = vec4(mask.rgb, 1.0);
    
    vec2 uv = TextureCoordsVarying.xy;
    float y;
    if (uv.y >= 0.0 && uv.y <= 0.5) {
        y = uv.y + 0.25;
    } else {
        y = uv.y - 0.25;
    }
    gl_FragColor = texture2D(Texture, vec2(uv.x,y));
}
