# Quill × Notepad++ — lista de paridade

Base: os 531 comandos de menu do Notepad++ (`sdk/include/menuCmdID.h`) mais recursos que não são menu.
`[x]` = já existe no Quill · `[ ]` = falta fazer · `[~]` = existe parcialmente (o que falta está escrito) · `[n/a]` = não faz sentido ou é impossível no macOS (com o motivo).

A cada item concluído, o autoteste (`app/src/SelfTest.mm`) ganha um passo e o CI precisa passar antes de marcar `[x]`.

---

## 1. Arquivo

- [x] Novo, Abrir, Fechar, Fechar todos, Fechar todos menos o atual
- [x] Fechar à esquerda / à direita / não modificados (menu da aba)
- [x] Salvar, Salvar como, Salvar cópia como, Salvar tudo
- [x] Recarregar do disco, Renomear
- [x] Reabrir aba fechada, Arquivos recentes, Limpar recentes
- [x] Imprimir
- [x] Copiar caminho / nome do arquivo, Mostrar no Finder, Abrir no Terminal
- [ ] `FILE_DELETE` — mover o arquivo atual para o Lixo
- [ ] `LOADSESSION` / `SAVESESSION` — sessões nomeadas (salvar e carregar arquivo de sessão)
- [ ] `OPEN_ALL_RECENT_FILE` — abrir todos os recentes
- [ ] `OPEN_DEFAULT_VIEWER` — abrir no app padrão do sistema
- [ ] `PRINTNOW` — imprimir direto, sem diálogo
- [ ] Opções de impressão (cabeçalho/rodapé, cores, margens, números de linha)
- [ ] `OPENFOLDERASWORKSPACE` / `CONTAININGFOLDERASWORKSPACE` — pasta como espaço de trabalho (hoje só o plugin Explorador)
- [ ] `CLOSEALL_BUT_PINNED` (depende de fixar aba, seção 9)
- [n/a] `OPEN_POWERSHELL` — adaptar: abrir no Terminal já existe; opcional abrir `pwsh` se instalado
- [ ] Abrir em nova instância (`GOTO_NEW_INSTANCE`, `LOAD_IN_NEW_INSTANCE`)
- [ ] Soltar arquivos na janela para abrir (verificar e testar)

## 2. Editar

### Básico
- [x] Recortar, Copiar, Colar, Apagar, Selecionar tudo, Desfazer, Refazer
- [x] Indentar / Desindentar (`INS_TAB`, `RMV_TAB`)
- [x] Duplicar linha, Mover linha acima/abaixo, Juntar linhas, Apagar linha
- [x] Comentar/descomentar linha (alternar) e em bloco
- [x] Somente leitura (por documento)
- [x] Copiar caminho completo e nome do arquivo
- [x] Completar palavra (`AUTOCOMPLETE_CURRENTFILE`)
- [ ] `TRANSPOSE_LINE` — trocar a linha atual com a anterior
- [ ] `SPLIT_LINES` — quebrar linhas na coluna de borda
- [ ] `BEGINENDSELECT` / `BEGINENDSELECT_COLUMNMODE` — marcar início/fim da seleção
- [ ] `BLOCK_COMMENT_SET` / `BLOCK_UNCOMMENT` — comentar / descomentar linhas separadamente (o Quill só alterna)
- [ ] `STREAM_UNCOMMENT` separado
- [ ] `RTL` / `LTR` — direção do texto
- [ ] `TOGGLESYSTEMREADONLY` — atributo somente leitura do arquivo no disco
- [ ] `SETREADONLYFORALLDOCS` / `CLEARREADONLYFORALLDOCS`
- [ ] `CURRENTDIRTOCLIP` — copiar a pasta atual
- [ ] `COPY_ALL_NAMES` / `COPY_ALL_PATHS` (e `DOCLIST_COPYNAMES/PATHS`)
- [ ] `COPY_LINK` — copiar o link sob o cursor
- [ ] `PASTE_AS_HTML` / `PASTE_AS_RTF` / copiar como HTML e RTF
- [ ] `COPY_BINARY` / `CUT_BINARY` / `PASTE_BINARY`
- [ ] `REDACT_SELECTION` — ocultar trecho selecionado
- [ ] `OPENSELECTEDFILETOEDIT` — abrir o arquivo cujo caminho está selecionado
- [ ] `OPENSELECTEDFILEFOLDERINEXPLORER` — mostrar esse arquivo no Finder
- [ ] `SEARCHONINTERNET` / `CHANGESEARCHENGINE` — pesquisar a seleção na web
- [ ] Painel de caracteres (`CHAR_PANEL`)
- [ ] Histórico da área de transferência (`CLIPBOARDHISTORY_PANEL`)
- [ ] Modo coluna: diálogo "Editor de colunas" (inserir texto ou números sequenciais) e `COLUMNMODE`/`COLUMNMODETIP` (hoje só ⌥+arrastar)

### Espaços e linhas
- [x] Remover espaços no fim (`TRIMTRAILING`)
- [x] Tabulações → espaços (`TAB2SW`); espaços iniciais → tabulações (`SW2TAB_LEADING`)
- [x] Remover linhas vazias (`REMOVEEMPTYLINES`)
- [ ] `TRIMLINEHEAD` — espaços no início das linhas
- [ ] `TRIM_BOTH` — nos dois lados
- [ ] `TRIMALL` — também tudo no meio (compactar)
- [ ] `EOL2WS` — fim de linha → espaço
- [ ] `SW2TAB_ALL` — todos os espaços → tabulações
- [ ] `REMOVEEMPTYLINESWITHBLANK` — remover linhas vazias ou só com espaços (conferir o comportamento)
- [ ] `BLANKLINEABOVECURRENT` / `BLANKLINEBELOWCURRENT`

### Ordenar e duplicadas
- [x] Ordem lexicográfica crescente / decrescente
- [x] Ignorando maiúsculas (crescente)
- [x] Numérica (crescente)
- [x] Remover duplicadas (qualquer posição) — `REMOVE_ANY_DUP_LINES`
- [ ] Ignorando maiúsculas, decrescente
- [ ] `SORTLINES_INTEGER_ASC/DESC`
- [ ] `SORTLINES_DECIMALCOMMA_ASC/DESC`
- [ ] `SORTLINES_DECIMALDOT_ASC/DESC`
- [ ] `SORTLINES_LOCALE_ASC/DESC` — pela localidade
- [ ] `SORTLINES_LENGTH_ASC/DESC` — por tamanho
- [ ] `SORTLINES_REVERSE_ORDER` — inverter ordem
- [ ] `SORTLINES_RANDOMLY` — embaralhar
- [ ] `REMOVE_CONSECUTIVE_DUP_LINES` — só duplicadas consecutivas

### Caixa
- [x] MAIÚSCULAS, minúsculas, Iniciais maiúsculas, inverter
- [ ] `PROPERCASE_FORCE` / `PROPERCASE_BLEND`
- [ ] `SENTENCECASE_FORCE` / `SENTENCECASE_BLEND`
- [ ] `RANDOMCASE`

### Data e hora
- [~] `INSERT_DATETIME_SHORT` — existe um formato; faltam longo e personalizado
- [ ] `INSERT_DATETIME_LONG`
- [ ] `INSERT_DATETIME_CUSTOMIZED`

### Múltiplos cursores
- [x] Adicionar próxima ocorrência, selecionar todas (diferencia maiúsculas)
- [ ] Variações com/sem maiúsculas e palavra inteira (`MULTISELECTALL*`, `MULTISELECTNEXT*`)
- [ ] `MULTISELECTUNDO` — desfazer última seleção
- [ ] `MULTISELECTSSKIP` — pular ocorrência

### Auto-completar
- [x] Completar palavras do documento e palavras-chave da linguagem
- [ ] `AUTOCOMPLETE` — completar função/palavra da linguagem com dicionário de API
- [ ] `AUTOCOMPLETE_PATH` — completar caminhos de arquivo
- [ ] `FUNCCALLTIP` / `_PREVIOUS` / `_NEXT` — dica de parâmetros de função

## 3. Pesquisar

- [x] Localizar, próximo, anterior, usar seleção
- [x] Substituir, substituir tudo, só na seleção
- [x] Diferenciar maiúsculas, palavra inteira, regex
- [x] Marcar todas as ocorrências / limpar marcações
- [x] Localizar em arquivos (e substituir em arquivos)
- [x] Ir para linha (linha:coluna), ir para parêntese correspondente
- [x] Alternar / próximo / anterior / limpar marcadores
- [x] Busca incremental básica (ao digitar)
- [ ] Modo de busca **Estendido** (`\n`, `\r`, `\t`, `\0`, `\x...`)
- [ ] Opção "`.` casa quebra de linha"
- [ ] Opção de direção (para cima/para baixo) e de "dar a volta" desligável
- [ ] Localizar em **todos os documentos abertos**; substituir em todos
- [ ] Localizar tudo no documento atual (lista de resultados)
- [ ] Contar ocorrências
- [ ] Janela de resultados: ir para próximo/anterior resultado (`GOTONEXTFOUND`, `GOTOPREVFOUND`), focar nos resultados (`FOCUS_ON_FOUND_RESULTS`), recolher/expandir, copiar resultados
- [ ] `FINDINCREMENT` — barra de busca incremental dedicada
- [ ] `VOLATILE_FINDNEXT` / `VOLATILE_FINDPREV` — localizar seleção sem mudar o campo de busca
- [ ] `SETANDFINDNEXT` / `SETANDFINDPREV` — definir termo e localizar
- [ ] `FINDCHARINRANGE` — localizar caracteres em um intervalo
- [ ] `SELECTMATCHINGBRACES` — selecionar tudo entre parênteses
- [ ] `CUTMARKEDLINES` / `COPYMARKEDLINES` / `PASTEMARKEDLINES` / `DELETEMARKEDLINES`
- [ ] `DELETEUNMARKEDLINES` / `INVERSEMARKS`
- [ ] Cinco estilos de marcação: `MARKALLEXT1..5`, `UNMARKALLEXT1..5`, `MARKONEEXT1..5`, `CLEARALLMARKS`
- [ ] `GOPREVMARKER1..5` / `GONEXTMARKER1..5` / `_DEF` — navegar entre marcações
- [ ] `MARK` — diálogo "Marcar" (com regex, marcar linhas, purgar)
- [ ] `STYLE1TOCLIP..5`, `ALLSTYLESTOCLIP`, `MARKEDTOCLIP` — copiar texto marcado
- [ ] `CHANGED_NEXT` / `CHANGED_PREV` / `CLEAR_CHANGE_HISTORY` — navegar e limpar histórico de alterações
- [ ] Marcador com cores/estilos diferentes e "Marcar linha" na busca
- [ ] Transparência e posição da janela de busca (adaptar para a barra)

## 4. Exibir

- [x] Tela cheia, Exibir espaços, fim de linha, guias de indentação, quebra de linha, zoom (+, −, restaurar)
- [x] Dobrar tudo / expandir tudo / alternar dobra atual
- [x] Mostrar/ocultar barra de status e barra de ferramentas
- [x] Próxima/anterior aba, ir para aba 1–9 (e última)
- [x] Painéis dos plugins no lado esquerdo/direito/inferior
- [~] `ALL_CHARACTERS` — existe espaços + fim de linha separados; falta o botão "todos os caracteres" e os caracteres de controle (`NPC`, `NPC_CCUNIEOL`)
- [ ] `TAB_SPACE` / `EOL` com opções individuais (setas de tab, estilo de EOL)
- [ ] `WRAP_SYMBOL` — símbolo de quebra de linha
- [ ] `POSTIT` — modo Post-it
- [ ] `DISTRACTIONFREE` — modo sem distrações
- [ ] `ALWAYSONTOP` — sempre no topo
- [ ] `SYNSCROLLV` / `SYNSCROLLH` — rolagem sincronizada entre vistas
- [ ] `ZOOM_SYNC` — zoom sincronizado
- [ ] `HIDELINES` — esconder linhas selecionadas
- [ ] `SUMMARY` — janela de resumo (caracteres, palavras, linhas, seleção)
- [ ] `FOLD_CURRENT` / `UNFOLD_CURRENT` (recolher / expandir só o nível atual)
- [ ] `FOLD_1..8` / `UNFOLD_1..8` — dobrar / expandir por nível
- [ ] `DOCLIST` — painel Lista de documentos (e `SWITCHTO_DOCLIST`)
- [ ] `DOC_MAP` — Mapa do documento
- [ ] `FUNC_LIST` — Lista de funções (com busca e ordenação) e `SWITCHTO_FUNC_LIST`; exportar (`EXPORT_FUNC_LIST_AND_QUIT`)
- [ ] `PROJECT_PANEL_1..3` — painéis de projeto (e `SWITCHTO_PROJECT_PANEL_*`)
- [ ] `FILEBROWSER` — painel de pasta como espaço de trabalho (hoje Explorador, falta ligar ao comando e ao `SWITCHTO_FILEBROWSER`)
- [ ] `MONITORING` — monitorar arquivo (`tail -f`)
- [ ] `TAB_MOVEFORWARD` / `TAB_MOVEBACKWARD` — mover aba com atalho
- [ ] `TAB_START` / `TAB_END` — ir para a primeira / última aba
- [ ] `TAB_COLOUR_NONE`, `TAB_COLOUR_1..5` — cor da aba
- [ ] `SWITCHTO_OTHER_VIEW`, `GOTO_ANOTHER_VIEW`, `CLONE_TO_ANOTHER_VIEW` — **duas vistas** lado a lado (divisão horizontal e vertical) com mover/clonar documento
- [ ] `GOTO_START` / `GOTO_END` — início / fim do arquivo
- [ ] `IN_FIREFOX` / `IN_CHROME` / `IN_EDGE` — abrir arquivo no navegador (no Mac: Safari, Chrome, Firefox, Edge)
- [n/a] `IN_IE` — Internet Explorer não existe; substituído por Safari

## 5. Codificação e fim de linha

- [x] Fim de linha: Windows (CRLF), Unix (LF), Mac (CR)
- [x] UTF-8, UTF-8 com BOM, UTF-16 BE/LE (com BOM), Windows-1252, ISO-8859-1, Mac Roman
- [x] Converter para outra codificação e reabrir com codificação
- [ ] UTF-16 BE/LE **sem BOM**
- [ ] `ANSI` (codificação local do sistema) e `CONV2_ANSI`
- [ ] Windows-1250, 1251, 1253, 1254, 1255, 1256, 1257, 1258
- [ ] ISO-8859-2, 3, 4, 5, 6, 7, 8, 9, 13, 14, 15
- [ ] DOS: 437, 720, 737, 775, 850, 852, 855, 857, 858, 860, 861, 862, 863, 865, 866, 869
- [ ] Chinês: Big5, GB2312 · Japonês: Shift-JIS · Coreano: Windows 949, EUC-KR
- [ ] Tailandês: TIS-620
- [ ] Cirílico: Mac Cyrillic, KOI8-U, KOI8-R
- [ ] Detecção automática melhor para essas codificações
- [ ] Preferências de codificação padrão por tipo de arquivo

## 6. Linguagem e estilos

- [x] ~100 linguagens com realce e dobra
- [x] Escolha manual da linguagem pelo menu
- [x] Detecção por extensão, nome de arquivo e primeira linha
- [ ] `USER_DLG` — **Linguagem definida pelo usuário (UDL)**: editor completo (palavras-chave, delimitadores, comentários, operadores, números, dobra, estilos)
- [ ] Importar / exportar UDL (XML do Notepad++), `OPENUDLDIR`, `UDLCOLLECTION_PROJECT_SITE`
- [ ] `LANGSTYLE_CONFIG_DLG` — **Configurador de estilos**: cor, fonte, tamanho, negrito/itálico por estilo e por linguagem
- [ ] Temas de estilo (importar `IMPORTSTYLETHEMES`, tema padrão, Obsidian, etc.)
- [ ] Lexers externos (`EXTERNAL`) — carregar lexer extra (`.dylib`)
- [ ] Palavras-chave extras e extensões personalizadas por linguagem
- [ ] Tabulação e indentação por linguagem
- [ ] Dobra personalizada, casamento de tags HTML/XML (destaque, ir para tag correspondente, selecionar tag), fechamento automático de tags
- [ ] Links clicáveis (⌘+clique abre URL e arquivo)
- [ ] Dicas de API / dicionário de funções (arquivos `.xml` de autocompletar)

## 7. Configurações

- [x] Preferências básicas (fonte, tabulação, tema, quebra de linha, margens, sessão, backup, codificação padrão)
- [x] Idioma da interface (inglês e português)
- [x] Gerenciar plugins (ativar/desativar, instalar `.dylib`, abrir pasta)
- [x] Restaurar a última sessão
- [ ] `SHORTCUT_MAPPER` — **Mapeador de atalhos** (editar atalhos de menu, macros, comandos Executar e plugins; detectar conflitos); `SHORTCUT_MAPPER_MACRO`, `SHORTCUT_MAPPER_RUN`
- [ ] `EDITCONTEXTMENU` — personalizar o menu de contexto
- [ ] `IMPORTPLUGIN` — importar plugin por menu (hoje pela janela de plugins)
- [ ] `PLUGINADM` — Administrador de plugins (lista, instalar, atualizar, remover, com catálogo)
- [ ] `TRAYICON` / `SYSTRAYPOPUP_*` — ícone na barra de menus (adaptar)
- [ ] Preferências completas, em categorias:
  - [ ] Geral (barra de abas: várias linhas, vertical, ocultar, duplo-clique fecha, botão de fechar, ícones; barra de ferramentas; localização)
  - [ ] Editor (tabulação por linguagem, largura da margem, cursor, rolagem, múltiplos cursores, scroll além do fim, EOL)
  - [ ] Cores de marcação e destaque
  - [ ] Novo documento (codificação, fim de linha, linguagem padrão)
  - [ ] Pasta padrão de abertura e salvamento, "lembrar a última pasta"
  - [ ] Associação de tipos de arquivo
  - [ ] Linguagem (lista de menus, tabulação por linguagem)
  - [ ] Destaque de sintaxe (ligar/desligar)
  - [ ] Auto-completar (função, palavra, caminho, a partir de N caracteres, dica de parâmetros, fechamento automático de aspas/parênteses/tags)
  - [ ] Backup (simples, detalhado, pasta própria) e salvar automaticamente a cada N minutos
  - [ ] Multi-instância e data
  - [ ] Delimitadores (seleção por delimitador, duplo-clique)
  - [ ] Realce de resultados e do histórico de alterações
  - [ ] Pesquisa (tamanho da janela, "confirmar substituir tudo", "preencher com seleção")
  - [ ] Configurações na nuvem (iCloud / pasta sincronizada)
  - [ ] Importação/exportação de todas as configurações
- [n/a] `UPDATE_NPP` — atualização automática do Notepad++; o Quill usa a página de releases

## 8. Macros e Executar

- [ ] `STARTRECORDINGMACRO` / `STOPRECORDINGMACRO` / `PLAYBACKRECORDEDMACRO`
- [ ] `SAVECURRENTMACRO` — salvar com nome e atalho
- [ ] `RUNMULTIMACRODLG` — executar N vezes / até o fim do arquivo
- [ ] Lista de macros salvas no menu Macro e edição (renomear, apagar, atalho)
- [ ] Gravar também buscas e substituições; reprodução rápida
- [ ] Menu **Executar**: executar comando (já via plugin Exec), lista de comandos salvos com atalho
- [ ] Executar: abrir a seleção no navegador, pesquisar no Google/Wikipedia, abrir arquivo no app padrão, enviar por e-mail

## 9. Janela e abas

- [x] Lista de abas no menu Janela, abas arrastáveis, menu de contexto da aba
- [x] Reabrir aba fechada
- [ ] `WINDOW_WINDOWS` — janela "Windows…" (lista de todos, salvar, fechar, ordenar em massa)
- [ ] `WINDOW_SORT_*` — ordenar abas por nome, caminho, tipo, tamanho, data (crescente/decrescente)
- [ ] `WINDOW_MRU_FIRST` / `MRU_LIMIT` — ordem de uso recente e Ctrl+Tab com lista
- [ ] `WINDOW_COPY_NAME` / `COPY_PATH`
- [ ] Fixar aba (`pinned`), bloquear aba (somente leitura sem fechar)
- [ ] Cor de aba por documento
- [ ] Mover aba entre janelas e para nova janela
- [ ] Barra de abas em várias linhas / vertical / ocultar
- [ ] `DROPLIST_LIST` / `DROPLIST_MRU_FIRST` — lista suspensa de abas

## 10. Ajuda e sistema

- [x] Ajuda e guia de plugins (dentro do app, em inglês e português)
- [ ] `ABOUT` — janela "Sobre" com versão, licença e créditos
- [ ] `DEBUGINFO` — informações para depuração (versão, plugins, caminhos)
- [ ] `CMDLINEARGUMENTS` — ajuda dos argumentos de linha de comando e suporte a `-n<linha>`, `-c<coluna>`, `-multiInst`, `-nosession`, `-ro`, `-l<linguagem>`
- [ ] `PROJECTPAGE` / `ONLINEDOCUMENT` / `FORUM` / `WIKIFAQ` / `HELP` — links úteis (apontando para o repositório do Quill)
- [ ] Ferramenta de linha de comando `quill` (instalar em `/usr/local/bin`)
- [ ] `EXECUTE_VALIDATE_SHORTCUTSXML` — validar atalhos
- [ ] Serviços do macOS (Abrir no Quill pelo Finder / menu de serviços)
- [ ] Quick Look / ícones de tipo de arquivo (opcional)

## 11. Ferramentas

- [ ] MD5: gerar do texto, de arquivos, copiar para a área de transferência
- [ ] SHA-1: idem
- [ ] SHA-256: idem
- [ ] SHA-512: idem

## 12. Plugins — o que falta para ficar no nível dos originais

### Comparar (Compare)
- [ ] Detectar linhas movidas
- [ ] Ignorar linhas vazias, caracteres específicos, comentários
- [ ] Comparar dois arquivos de uma pasta e comparar pastas
- [ ] Comparar com Git (versão do HEAD, commit ou branch)
- [ ] Mostrar diferenças dentro das próprias abas (sem janela separada), com navegação sincronizada
- [ ] Aplicar diferença: copiar bloco do lado esquerdo para o direito e vice-versa
- [ ] Barra de navegação com marcas e opção de "primeiro arquivo à esquerda"

### JSON
- [ ] Mostrar o caminho do JSON ao clicar e copiar
- [ ] Comparar / ordenar arrays; edição na árvore
- [ ] JSON Lines, JSON5; validação com JSON Schema
- [ ] Formatação com estilos (quebrar objetos curtos, vírgula no começo)

### XML
- [ ] Validar com XSD, DTD e RelaxNG
- [ ] Transformar com XSLT
- [ ] Mostrar caminho XPath do nó atual e avaliar XPath com resultado na lista
- [ ] Converter XML ↔ texto; remover declarações e comentários
- [ ] Pretty print com opções (atributos em linhas separadas, preservar linhas em branco)
- [ ] Verificar sintaxe ao digitar e marcar o erro no editor
- [ ] Fechar tags automaticamente

### Executar (NppExec)
- [ ] **Linguagem de script**: variáveis (`set`, `unset`), `if`/`goto`/labels, `npp_*` (abrir, salvar, trocar de aba, executar menu, mensagens), `sci_*`, `env_*`, `cd`, `echo`, `inputbox`, `con_*`
- [ ] Salvar, editar, nomear e executar scripts; script de inicialização
- [ ] Executar ao salvar / ao abrir (eventos)
- [ ] Console: entrada de linha, histórico, cores configuráveis, filtros de erro com regex, ir para o erro clicando
- [ ] Executar em segundo plano e vários processos
- [ ] Menu de comandos do usuário com atalho para cada script
- [ ] Console integrado como terminal (TTY) para programas interativos

### Explorador
- [ ] Mostrar tamanho, data e permissões
- [ ] Arrastar para fora do app e abrir vários arquivos de uma vez
- [ ] Atualizar sozinho quando a pasta muda (FSEvents)
- [ ] Favoritos, histórico e localizar na pasta pelo painel
- [ ] Filtros por tipo e por nome (várias linhas)

### Markdown
- [ ] Exportar para PDF
- [ ] Temas CSS personalizados
- [ ] Sincronizar rolagem nos dois sentidos
- [ ] Matemática (KaTeX) e diagramas (Mermaid)

### Verificação ortográfica (DSpellCheck)
- [ ] Respeitar o realce de sintaxe: verificar só comentários e strings em código
- [ ] Vários idiomas ao mesmo tempo e dicionário do usuário editável
- [ ] Ignorar palavras em maiúsculas, com números, URLs e e-mails (opções)
- [ ] Lista de erros no painel e "corrigir todos"

### Hex
- [ ] Mostrar os bytes do **arquivo no disco** (codificação original), não do texto em UTF-8
- [ ] Inserir e apagar bytes; colar bytes
- [ ] Seleção de intervalo, copiar como texto/hex
- [ ] Comparar duas vistas hex; marcadores
- [ ] 8 / 16 / 32 colunas; visualização de números (u8–u64, float, endianness)
- [ ] Hex ao vivo dentro da aba (sem janela separada)

### FTP
- [ ] Reutilizar a conexão (hoje cada operação abre uma nova, é mais lento)
- [ ] Fila e barra de progresso de transferências; cancelar
- [ ] Chave SSH com senha (passphrase) pelo app / Keychain
- [ ] Proxy, modo ativo/passivo, codificação dos nomes
- [ ] Sincronizar e comparar pasta local e remota
- [ ] Baixar e enviar pastas inteiras
- [ ] Mostrar permissões e alterá-las (chmod)

## 13. Infraestrutura e qualidade

- [ ] Fazer o autoteste cobrir cada item deste arquivo
- [ ] Teste de desempenho com arquivos grandes (100 MB+) e linhas muito longas
- [ ] Teste de abrir muitos arquivos de uma vez
- [ ] Acessibilidade (VoiceOver) e navegação por teclado completa
- [ ] Notarização opcional (se você criar uma conta de desenvolvedor Apple)
- [ ] Atualização automática do Quill (verificar release novo no GitHub)
- [ ] Mensagem de erro e relatório de falha (log em `~/Library/Logs/Quill`)
- [ ] Atalhos de teclado compatíveis com o Notepad++ (quando não conflitam com o macOS)

---

## Como usar esta lista

1. O trabalho segue a ordem das seções, começando pelas funções que o usuário disse que mais usa.
2. Cada bloco termina com commit, push, CI verde e este arquivo atualizado.
3. Só se diz "terminado" quando não sobrar `[ ]` aqui, a não ser os itens `[n/a]`, que ficam explicados.
