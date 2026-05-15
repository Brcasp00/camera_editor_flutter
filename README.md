# Detector de Bordas

Aplicativo mobile em Flutter que captura uma imagem pela câmera do celular e
exibe uma versão processada destacando as bordas, simulando aplicações reais
de visão computacional (leitura de documentos, análise de formas, etc.).

Este projeto foi desenvolvido como atividade acadêmica de introdução ao
processamento de imagens.

## Funcionalidades

### Obrigatórias (escopo da atividade)

- Captura de foto pela câmera do dispositivo
- Exibição da imagem original
- Geração automática de uma versão em **tons de cinza**
- Aplicação de uma técnica simples de **detecção de bordas**
- Visualização da imagem processada
- Interface organizada com **navegação** entre tela de captura e tela de
  resultado

### Extras (além do escopo)

Estas funcionalidades não fazem parte do enunciado da atividade, mas foram
incluídas para enriquecer o projeto:

- **Slider de threshold** para ajustar interativamente o ponto de corte da
  detecção de bordas (0 a 255)
- **Alternância em tempo real** entre as três visualizações (original /
  cinza / bordas) via `SegmentedButton`
- **Carimbo de data e hora** da captura
- **Geolocalização** (latitude/longitude) da captura via GPS
- **Exportar resultado** para a galeria do dispositivo

## Algoritmo de detecção de bordas

A detecção de bordas é feita por **diferença entre pixels vizinhos**, uma
técnica simples baseada no gradiente da intensidade luminosa.

Para cada pixel `(x, y)` da imagem em tons de cinza:

1. Calcula-se a diferença absoluta da luminância para o vizinho à direita:
   `dx = |L(x+1, y) - L(x, y)|`
2. Calcula-se a diferença absoluta da luminância para o vizinho abaixo:
   `dy = |L(x, y+1) - L(x, y)|`
3. A magnitude do gradiente é aproximada por `M = dx + dy`
4. O pixel de saída é **branco (255)** se `M > threshold`, ou **preto (0)**
   caso contrário

Isso produz uma imagem binária com os contornos realçados em branco sobre
fundo preto. É uma variação simplificada do operador de Roberts.

O processamento roda em um **isolate separado** (`compute()`), evitando
travar a UI thread em imagens grandes.

## Estrutura do código

```
lib/
├── main.dart              # Entrada do app + tema
├── capture_page.dart      # Tela 1: captura via câmera
├── result_page.dart       # Tela 2: visualização e processamento
└── image_processor.dart   # Funções de processamento (rodam em isolate)
```

## Dependências principais

| Pacote                      | Uso                                    |
|-----------------------------|----------------------------------------|
| `image_picker`              | Captura de foto pela câmera            |
| `image`                     | Decode/encode + grayscale + pixels     |
| `geolocator`                | (extra) Coordenadas GPS                |
| `permission_handler`        | (extra) Permissões em runtime          |
| `image_gallery_saver_plus`  | (extra) Salvar resultado na galeria    |
| `intl`                      | (extra) Formatação de data/hora        |

## Como rodar

Pré-requisitos: Flutter 3.3+ e um dispositivo Android conectado (ou
emulador) com câmera funcional.

```bash
flutter pub get
flutter run
```

## Permissões necessárias (Android)

Já declaradas em `android/app/src/main/AndroidManifest.xml`:

- `CAMERA` — captura de foto
- `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` — geolocalização (extra)
- `READ_EXTERNAL_STORAGE` / `WRITE_EXTERNAL_STORAGE` / `READ_MEDIA_IMAGES` —
  salvar imagem na galeria (extra)

## Fluxo de uso

1. App abre na tela de captura com botão "Capturar Foto"
2. Usuário toca no botão → câmera nativa abre
3. Ao confirmar a foto → navega automaticamente para a tela de resultado
4. A imagem é decodificada, convertida para tons de cinza e tem suas bordas
   detectadas em background (isolate)
5. Usuário alterna entre original / cinza / bordas com o `SegmentedButton`
6. Usuário pode ajustar o threshold com o slider (reprocessa ao soltar)
7. Botão "Nova Captura" volta para a tela inicial; "Salvar Bordas" exporta
   para a galeria
