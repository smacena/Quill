# Quill

Editor de texto e código **100% nativo para macOS**, inspirado no Notepad++, com o mesmo motor de edição (Scintilla + Lexilla) e uma **API de plugins compatível com a do Notepad++**.

*[English version](README.md)*

## Instalar

### Opção 1: baixar pronto
1. Abra a página de [Releases](../../releases/tag/latest) e baixe **Quill-macOS.zip**.
2. Descompacte e arraste **Quill.app** para **Aplicativos**.
3. Na primeira vez, clique com o **botão direito → Abrir** (o app é assinado localmente, sem conta paga da Apple).
   Se o macOS ainda bloquear: `xattr -dr com.apple.quarantine /Applications/Quill.app`

### Opção 2: compilar no seu Mac
Requisitos: macOS 13+, Xcode Command Line Tools (`xcode-select --install`) e CMake (`brew install cmake`).

```bash
./build.sh install
```

O app fica em `build/app/Quill.app` e é copiado para `/Applications`. Funciona em Apple Silicon e Intel (binário universal).

## Recursos do editor

- Abas com reordenação por arrastar, menu de contexto, reabrir aba fechada (⇧⌘T)
- Realce de sintaxe para ~100 linguagens, dobra de código, números de linha
- Localizar/substituir com expressões regulares, marcar todas, **Localizar em arquivos** (⇧⌘F)
- Múltiplos cursores (⌥⌘D próxima ocorrência, ⇧⌘L todas), seleção retangular (⌥ + arrastar)
- Operações de linha: duplicar, mover, ordenar, remover duplicadas/vazias, aparar espaços
- Comentar/descomentar (⌘/), maiúsculas/minúsculas, indentação, tabs ↔ espaços
- Codificações: UTF-8, UTF-8 BOM, UTF-16 LE/BE, Windows-1252, ISO-8859-1, Mac Roman; fim de linha LF/CRLF/CR
- Marcadores (⌘F2 / F2), ir para linha (⌘L), parêntese correspondente, completar palavras
- Histórico de alterações na margem, destaque da palavra selecionada
- Tema claro/escuro automático, sessão restaurada ao abrir, **alterações não salvas preservadas** ao sair
- Detecta arquivos alterados por outros programas
- Interface em **Português** e **Inglês** (Quill → Language / Idioma)

## Plugins incluídos

| Plugin | O que faz |
|---|---|
| **Comparar** | Diferenças lado a lado com aba anterior/próxima, versão salva, área de transferência ou dois arquivos; destaque por caractere e rolagem sincronizada |
| **Visualizador JSON** | Árvore navegável, formatar, compactar, ordenar chaves, validar com posição do erro |
| **Ferramentas XML** | Pretty print, linearizar, verificar sintaxe, XPath, escapar entidades |
| **Executar** | Roda comandos e scripts (⌘R executa o arquivo atual) com console, variáveis no estilo NppExec e links clicáveis `arquivo:linha` |
| **Explorador** | Painel de pastas com criar, renomear, mover para o Lixo, arrastar e soltar, filtro |
| **Visualizador Markdown** | Pré-visualização ao vivo, exportar/copiar HTML |
| **Verificação ortográfica** | Usa o corretor do macOS, sugestões no menu de contexto |
| **Editor hexadecimal** | Ver e editar bytes, ir para posição, buscar bytes |
| **FTP** | SFTP, FTP e FTPS; senhas no Keychain; abrir arquivo remoto e enviar automaticamente ao salvar |

## Plugins de terceiros

Plugins são arquivos `.dylib` em `~/Library/Application Support/Quill/plugins/` (menu **Plugins → Abrir pasta de plugins**).

As DLLs de Windows do Notepad++ não rodam no macOS, mas plugins de **código aberto** podem ser recompilados com o SDK em `sdk/include`, que reproduz a API do Notepad++ (`setInfo`, `getFuncsArray`, `beNotified`, `messageProc`, mensagens `NPPM_*`/`SCI_*`, painéis `NPPM_DMMREGASDCKDLG`). Veja o [guia de plugins](PLUGINS.md).

## Licença

GPL v3. Usa Scintilla e Lexilla (licença Scintilla), md4c (MIT) e dados de linguagem do projeto Notepad++ (GPL).
