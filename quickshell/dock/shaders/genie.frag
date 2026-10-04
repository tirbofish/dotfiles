#version 440
// Cantos arredondados da janela (distância a um retângulo arredondado) e um
// esmaecer curto no fim, quando a janela já está do tamanho do ícone.
layout(location = 0) in vec2 texCoord;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    float radius;
    vec4 sourceRect;
    vec4 targetRect;
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 size = max(sourceRect.zw, vec2(1.0));
    vec2 p = texCoord * size;
    vec2 q = abs(p - size * 0.5) - (size * 0.5 - vec2(radius));
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
    float edge = 1.0 - smoothstep(-1.0, 0.5, d);
    float fade = 1.0 - smoothstep(0.9, 1.0, progress);
    fragColor = texture(source, texCoord) * edge * fade * qt_Opacity;
}
