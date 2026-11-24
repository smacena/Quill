# Quill — tudo que precisa ser feito

Visão geral. A lista detalhada dos itens do Notepad++ está em `docs/FULL_PARITY.md` (1.499 textos + comportamento e formatos).

## Decisões já fechadas (viram tarefas)
- [ ] ANSI passa a ser Windows-1252 (Mac Roman fica como opção separada)
- [ ] Idiomas do Notepad++ (`nativeLang/*.xml`) carregados em tempo de execução; inglês e português completos
- [ ] Ícones na interface: SF Symbols (sem desenho próprio de 40 ícones)
- [ ] Scintilla e Lexilla alinhados à versão de referência (commit `d0bf05c` do Notepad++)
- [ ] Formatos de configuração do Notepad++ lidos e gravados (`config.xml`, `shortcuts.xml`, `stylers.xml`, `langs.xml`, `session.xml`, `contextMenu.xml`, UDL)
- [ ] Menu "Importar configuração do Notepad++" (pede a pasta de origem)
- [ ] Aviso para arquivos acima de 1 GB antes de abrir, com opção de abrir mesmo assim
- [ ] Catálogo de plugins consulta a lista oficial do Notepad++
- [ ] Logs em `~/Library/Logs/Quill/`; backups em `~/Library/Application Support/Quill/`
- [ ] Fonte padrão Menlo; tema segue o macOS; idioma inicial pelo sistema
- [ ] Sem notarização

## Integração com o macOS
- [ ] Ícone na barra de menus
- [ ] Registro como editor de texto e código (Finder, "Abrir com")
- [ ] Serviços do macOS e "Abrir no Quill" no Finder
- [ ] Terminal.app na pasta do arquivo
- [ ] Navegadores: Safari e os outros instalados (Chrome, Firefox, Edge)
- [ ] Impressão pelo diálogo do macOS
- [ ] Comando `quill` em `/usr/local/bin` (instalado pelo `build.sh`, pede senha uma vez)
- [ ] Switches de linha de comando do Notepad++ (`-n`, `-c`, `-ro`, `-l`, `-nosession`, `-multiInst` etc.)

## Atalhos e comportamento
- [ ] Atalhos do Notepad++ com ⌘ e ⌥ no lugar de Ctrl e Alt
- [ ] Conflitos com o macOS resolvidos a favor do macOS, com o original disponível no mapeador
- [ ] Mapeador de atalhos completo
- [ ] Multi-instância disponível como opção

## Plugins
- [ ] Os 9 plugins atuais revisados contra o comportamento do original
- [ ] NppExec: linguagem de script completa
- [ ] NppExport, Converter, mimeTools e demais plugins de código aberto do pacote padrão
- [ ] Gerenciador de plugins com catálogo
- [ ] Plugins que são DLL de Windows: aparecem como indisponíveis, com motivo
- [ ] SDK: documentação das mensagens, exemplo mínimo, teste no CI, pacote para baixar, lista do que não é suportado, versão da API

## Qualidade e testes
- [ ] Autoteste (`app/src/SelfTest.mm`) com um passo para cada item implementado
- [ ] Testes de regex
- [ ] Arquivos de teste do próprio Notepad++
- [ ] Teste com arquivo de 1 GB e linhas muito longas
- [ ] Acessibilidade: VoiceOver e teclado completo
- [ ] Interface em inglês e português revisada tela a tela

## Entrega
- [ ] Release `latest` com `Quill-macOS.zip` a cada bloco que passa no CI
- [ ] Versão final publicada e anunciada ao dono do projeto
- [ ] README.md, README.pt-BR.md, PLUGINS.md e docs atualizados

## Fora do Quill (outro projeto)
- [ ] SimpMusic (iPhone): lista de checkboxes do que falta (aguarda a referência)

## Ações suas (quando o projeto acabar)
- [ ] Apagar o branch `ci-results` no GitHub
