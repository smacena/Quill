# Verificação: Notepad++ original × Quill (macOS)

Fonte: clone do repositório oficial `notepad-plus-plus/notepad-plus-plus` (commit `f763171`).
Regra: o que tem equivalente no Mac é adaptado, não excluído. Só fica como impossível o que não tem nenhuma forma de ser feito no Mac, com o motivo.

## 1. Inventário do Notepad++ (fonte oficial)

| Recurso | Quantidade no original | Onde está | No Quill hoje | Adaptação no Mac |
|---|---|---|---|---|
| Comandos de menu (IDM_*) | 568 | `PowerEditor/src/menuCmdID.h` | 63 ligados | Igual; atalhos com ⌘/⌥ |
| Idiomas de interface | 96 | `PowerEditor/installer/nativeLang/*.xml` | 2 (inglês e português, no código) | Carregar os 96 XML em tempo de execução |
| Temas de cor | 22 | `PowerEditor/installer/themes/*.xml` | 0 carregados (2 paletas fixas) | Igual; o tema padrão segue o macOS |
| Parsers da Lista de funções | 48 | `PowerEditor/installer/functionList/` | 0 | Igual |
| Arquivos de autocompletar (APIs) | 34 | `PowerEditor/installer/APIs/` | 0 | Igual |
| Parâmetros de linha de comando | 27 | `PowerEditor/src/*.cpp` | 0 (só caminhos de arquivo) | Igual; comando `quill` em `/usr/local/bin` |
| Arquivos de configuração | 6 + UDL | `config.xml`, `shortcuts.xml`, `stylers.xml`, `langs.xml`, `session.xml`, `contextMenu.xml` | 0 lidos ou gravados | Mesmo formato; pasta `~/Library/Application Support/Quill/` |
| Plugins empacotados (instalador) | 7 DLL | `PowerEditor/installer/*.nsi` | 4 equivalentes (Comparar, XML, Hex, Ortografia) | Ver seção 2 |
| Arquivos de teste do próprio projeto | 2 | `PowerEditor/installer/filesForTesting/` | 0 usados nos testes | Usar os 2 e acrescentar testes próprios |

## 2. Plugins empacotados pelo instalador

| Plugin (DLL original) | Tem código-fonte aberto? | No Quill | Ação |
|---|---|---|---|
| ComparePlugin | Sim | Comparar (reescrito) | Revisar contra o original e portar o código |
| XMLTools | Sim | XML Tools (reescrito) | Revisar contra o original e portar |
| HexEditor | Sim | Editor hexadecimal (reescrito) | Revisar contra o original e portar |
| DSpellCheck | Sim | Verificação ortográfica (reescrito) | Revisar; usar o corretor do macOS |
| Converter | Sim (`npp-plugins/converter`, GPL) | Não | Portar do código-fonte |
| NppExport | Sim (`chcg/NPP_ExportPlugin`) | Não | Portar do código-fonte |
| mimeTools | Sim (`npp-plugins/mimetools`, GPL) | Não | Portar do código-fonte |

Plugins que o Plugins Admin do Notepad++ instala (NppExec, FTP, Markdown, JSON Viewer, Explorer, Light Explorer e outros): ver a lista oficial `notepad-plus-plus/nppPluginList`. No Quill, os que já existem estão em 2; os demais são pendentes.

## 3. Situação dos itens de menu

Dos 568 comandos do `menuCmdID.h`, 63 estão ligados a uma função no Quill (`MainWindowController+Npp.mm`). Os outros 505 ainda não têm função correspondente no app. Dentro desses, alguns são exclusivos do Windows e precisam de adaptação antes de serem considerados impossíveis (ver seção 4).

## 4. Itens que precisam de adaptação (não de exclusão)

- Atualização automática (WinGup) → verificação manual de releases no GitHub.
- Registro do Windows → `Info.plist` e preferências do macOS.
- Modo administrador (UAC) → pedido de senha de administrador do macOS.
- Explorer / cmd / PowerShell → Finder / Terminal.
- Internet Explorer / Edge / Chrome / Firefox → navegadores instalados no Mac.
- Bandeja do sistema → ícone na barra de menus.
- Caminhos de rede UNC → caminhos `smb://`.
- Atributo somente leitura do Windows → permissão de arquivo do macOS.
- Encerramento de sessão do Windows → aviso ao encerrar o sistema com dados não salvos.

## 5. Impossível no Mac (sem nenhuma forma de adaptar)

- Windows XP (sistema inexistente no Mac).
- Execução direta das DLLs de Windows (binário de outro sistema). Os plugins de código aberto são portados do código-fonte; os que só existem como DLL ficam indisponíveis, com o motivo.

## 6. Conclusão da verificação

- O que está no Quill e confere com o original: abas, abrir e salvar com codificações, busca e substituição com regex, busca em arquivos, realce de sintaxe (98 linguagens), dobra, sessão, backup, marcadores, ordenação e transformações de linha, caixa, hash, 7 plugins reescritos.
- O que falta de forma grande: 96 idiomas do original, 22 temas, arquivos de configuração no formato do Notepad++, linha de comando, Lista de funções, autocompletar com APIs, 505 comandos de menu, plugins portados (Converter, NppExport, mimeTools e os do Plugins Admin).
- Pendente de verificação linha a linha: o comportamento de cada função já existente, comparado com o original. Isso exige teste item por item e não está feito.
