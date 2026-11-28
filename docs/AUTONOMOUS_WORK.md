# Regras permanentes de trabalho (vale para qualquer trabalho)

Cole este arquivo, ou a seção "Pedido curto", no início de qualquer sessão de trabalho.

## Pedido curto (para colar)

Trabalhe de forma autônoma e completa até o fim do projeto indicado.

- Objetivo: 100% do projeto de referência, funcionalidade por funcionalidade. Aparência segue a plataforma solicitada, não precisa ser pixel idêntica.
- Não pare para reportar que um bloco terminou. Quando acabar um bloco, comece o seguinte.
- Não precisa gerar relatório de tudo que está fazendo, só as mais pertinentes.
- Não faça perguntas de rotina. Use o padrão já definido no repositório. Pergunte só se houver bloqueio real que eu precise resolver (diga exatamente qual), por exemplo credencial que não existe, acesso negado ou decisão que mude o escopo.
- Dúvidas que dependam de decisão minha devem ser tratadas no início, na lista de pendências, e não no meio do trabalho.
- Ao terminar tudo, entregue um resumo único: o que ficou igual, o que é diferente, o que é impossível (com motivo) e onde está o resultado.
- Se houverem objeções devido as regras desse documento que sejam apresentadas no início para serem tratadas.
- Se o limite semanal chegar a 90% durante o trabalho, finalize a sessão, bloco, implementação que esteja fazendo e pare em seguida e me pergunte se deve continuar o trabalho.

## Regras técnicas

- Lista de trabalho: a do projeto (a lista que for criada a partir da referência).
- Cada item só vira `[x]` depois de implementado e testado.
- Commits pequenos e frequentes, com a identidade do dono do projeto e sem citar ferramentas de IA em commits, código ou docs, exceto em situações que precise criar o CLAUDE.md, por exemplo.
- Textos de interface precisam ser discutido no início (por exemplo, idiomas).
- Não apagar branches, não reescrever histórico e não publicar nada fora do repositório sem autorização explícita.

## Entrada que só o dono pode dar (uma vez)

- Sem restrições aqui por enquanto.
## Ordens permanentes (não me faça repetir)

1. **Montar sozinho todo ambiente de teste.** Servidores, máquina limpa, tela virtual,
   leitor de tela, impressora virtual. "Não tenho o ambiente" nunca é motivo para não testar.
   O que for impossível aqui, você diz no relatório em vez de pular calado.
2. **Testar o que eu vou usar, não o seu build.** O produto é o .app dentro do .dmg,
   instalado em /Applications num macOS sem ferramentas de desenvolvedor. Um programa que
   só roda na sua pasta de build não está testado.
3. **Testar fora do padrão.** Todos os idiomas, todos os temas, modo claro e escuro,
   primeira execução sem configuração nenhuma. É aí que moram os piores defeitos; em inglês
   com o tema padrão tudo parece funcionar.
4. **Testar como pessoa, não como script.** Foco do teclado ao abrir, queda do programa
   (kill -9) com texto não salvo, arquivo binário, arquivo gigante, nome com acento,
   arquivo somente leitura, atualizar de uma versão para outra, desinstalar sem deixar lixo.
5. **Todo defeito corrigido vira teste permanente** (autoteste ou CI), para não voltar.
   E ao achar um defeito, procure o mesmo padrão no resto do código antes de seguir.
6. **Só marque um item como pronto depois de comparar com o código do Notepad++ e testar.**
   Nada de marcar porque a função existe.
7. **Não diga "terminei" enquanto houver item sem teste.** No relatório, liste separado:
   feito, testado, não testado e por quê.
8. **Não pergunte o óbvio.** Decida, faça e registre. Pergunte só se uma decisão já fechada
   precisar mudar ou se houver bloqueio real.
9. **Poucos relatórios, curtos, só no fim de cada bloco.** Não me conte que compilou nem que
   o autoteste passou.

## Específico do macOS

- Você roda num container Linux: **não dá para compilar nem abrir o programa aqui**. Diga isso
  na primeira mensagem e use **GitHub Actions com runner macOS** (macos-14/macos-15) para
  compilar, testar, tirar capturas de tela e empacotar. Não finja ter testado.
- **O .app precisa trazer as dependências dentro dele** (macdeployqt ou equivalente), incluindo
  o plugin de plataforma cocoa. No Linux esse foi o pior defeito: o pacote instalava e o
  programa não abria janela nenhuma num sistema limpo.
- **Assinatura e notarização.** Um .dmg baixado sem assinar é barrado pelo Gatekeeper com
  "arquivo danificado". Teste o caminho real: baixar, montar, arrastar e abrir.
- **Apple Silicon e Intel**: diga em qual arquitetura testou e, se for universal, teste as duas.
- **Permissões do sistema** (acesso a Documentos, Downloads, Área de Trabalho) só aparecem num
  Mac limpo, não no seu build.
- **Atalhos e menus do Mac**: Cmd em vez de Ctrl, barra de menus global, menu do aplicativo
  (Quill > Ajustes, Sobre, Serviços, Ocultar, Sair), nomes das janelas padrão do sistema.
- **Acessibilidade**: o leitor de tela é o VoiceOver, não o Orca.
- **Modo escuro do sistema**: o programa tem que acompanhar a troca sem reiniciar.
- **Release**: só com CI verde e com o .dmg aberto num macOS limpo. Repositório privado impede
  download anônimo.
