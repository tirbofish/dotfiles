#version 440
// Efeito "gênio" do macOS: a janela escorre para o Dock como um funil.
// A malha (GridMesh) cobre a imagem da janela; cada vértice é levado do
// retângulo da janela (sourceRect) para o lugar no Dock (targetRect).
// As linhas de baixo entram primeiro e as laterais se curvam em direção ao
// ícone, o que dá o formato de funil. progress: 0 = janela, 1 = no Dock.
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 texCoord;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    float radius;
    vec4 sourceRect;
    vec4 targetRect;
};

void main() {
    vec2 uv = qt_MultiTexCoord0;
    float t = clamp(progress, 0.0, 1.0);
    float bend = smoothstep(0.0, 0.42, t);
    float slide = smoothstep(0.22, 1.0, t);
    float v = uv.y;
    // Quanto cada linha já "entrou": as de baixo saem na frente.
    float row = clamp(slide * 1.6 - (1.0 - v) * 0.6, 0.0, 1.0);
    // As laterais afinam primeiro embaixo, depois a janela toda.
    float squeeze = max(bend * v * v, row);
    float left = mix(sourceRect.x, targetRect.x, squeeze);
    float right = mix(sourceRect.x + sourceRect.z, targetRect.x + targetRect.z, squeeze);
    float x = mix(left, right, uv.x);
    float y = mix(sourceRect.y + v * sourceRect.w, targetRect.y + v * targetRect.w, row);
    texCoord = uv;
    gl_Position = qt_Matrix * vec4(x, y, 0.0, 1.0);
}
