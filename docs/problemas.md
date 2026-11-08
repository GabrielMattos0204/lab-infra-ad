# Problemas encontrados e soluções

Registro dos erros reais durante o laboratório. Cada item traz sintoma, causa e correção.

## 1. VirtualBox: "Configurações inválidas detectadas"

**Sintoma:** aviso ao trocar o controlador gráfico da VM.
**Causa:** VMSVGA é o controlador indicado para convidados Linux; para Windows é VBoxSVGA.
**Correção:** troca para VBoxSVGA, 128 MB de vídeo, aceleração 3D habilitada.

## 2. VM congelando ao abrir Win+R

**Sintoma:** travamento total ao abrir `sysdm.cpl`.
**Causa:** hipervisor do Windows ativo por causa do WSL2, forçando o VirtualBox ao modo emulado, com apenas 2 núcleos físicos.
**Correção:** `bcdedit /set hypervisorlaunchtype off` e reinício. Reverter com `auto` para voltar a usar WSL2.

## 3. bcdedit retorna "acesso negado"

**Causa:** comando exige terminal elevado.
**Correção:** abrir PowerShell como Administrador.

## 4. DNS apontando para 127.0.0.1 nas duas placas

**Sintoma:** servidor sem resolução de nomes externos após a promoção.
**Causa:** o DNS foi definido em ambas as interfaces, incluindo a NAT.
**Correção:** `Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ResetServerAddresses`. A placa de domínio mantém 127.0.0.1; a de internet volta ao DHCP. Encaminhadores configurados no serviço DNS.

## 5. Usuária comum não consegue logar no controlador de domínio

**Sintoma:** "O método de entrada não é permitido".
**Causa:** por padrão só administradores têm logon local em DC.
**Correção:** liberado "Allow log on locally" para os grupos na Default Domain Controllers Policy.

## 6. Here-string corrompe o `.gitignore`

**Sintoma:** arquivo gravado como `ogs/` e `.html`, sem o primeiro caractere de cada linha.
**Correção:** `Set-Content .gitignore -Value @("logs/","*.html")`. Para arquivos longos, criar no VS Code em vez do terminal.

## 7. `Add-ADGroupMember` não gera erro em membro repetido

**Sintoma:** segunda execução do provisionamento registrava `OK` nos vínculos, quebrando a idempotência.
**Correção:** consultar `Get-ADGroupMember` antes e registrar `SKIP` quando o membro já existe.

## 8. Contagem de contas bloqueadas vazia

**Sintoma:** o monitor detectava a conta, mas `Contas bloqueadas:` saía sem número.
**Causa:** `Search-ADAccount` retornou objeto único, e objeto único não expõe `.Count` de forma confiável.
**Correção:** envolver em `@()` para forçar coleção.

## 9. Bloqueio de conta expirando durante o teste

**Sintoma:** segunda checagem mostrava "Nenhuma conta bloqueada".
**Causa:** a política de duração é de 15 minutos e o teste foi feito depois disso. Não era defeito.
**Correção:** refazer o bloqueio e executar a checagem imediatamente.

## 10. Tarefa agendada não gravava no log

**Sintoma:** tarefa executava (`LastRunTime` atualizado) mas o log não crescia.
**Causa:** execução com `-File` no contexto de serviço não gravava no arquivo.
**Correção:** ação alterada para `-Command` com `&` e redirecionamento, e execução sob conta com perfil carregado.

## 11. Logon de usuária comum volta a falhar após reexecutar o provisionamento

**Sintoma:** "O método de entrada que você está tentando usar não é permitido", mesmo com a senha recém-redefinida.

**Causa:** o provisionamento remove e recria a estrutura com outra nomenclatura de grupos. A Default Domain Controllers Policy continuava referenciando os grupos antigos, que deixaram de existir, e a usuária não estava coberta por nenhum grupo válido.

Grupos antigos que precisaram ser removidos da política: `GRP_Financeiro`, `GRP_RH`, `GRP_TI`.

**Correção:** atualizar "Allow log on locally" na Default Domain Controllers Policy, substituindo os grupos antigos por `GG_Financeiro`, `GG_TI` e `GG_Operacao`, seguido de `gpupdate /force`.

**Lição:** reconstruir ambiente quebra referências. Política de direito de logon aponta para grupo, e grupo apagado não cobre ninguém.

**Complementação:** o grupo `GG_HelpDesk` também precisou ser incluído em "Allow log on locally". O usuário de teste estava apenas nesse grupo, não no `GG_TI`, e por isso o logon continuava negado mesmo após a correção dos grupos antigos.

**Segunda lição:** direito de logon se concede a todos os grupos que precisam entrar na máquina, e o usuário de teste tem que estar no grupo certo. Grupo existir não basta; o vínculo é que vale.

## 12. Delegação de senha não funciona para usuário em OU filha

**Sintoma:** "Access is denied" ao tentar redefinir senha, mesmo com o usuário no grupo delegado.

**Causa:** o ACE foi criado por PowerShell sem sinalizador de herança, aplicando-se apenas à OU onde foi definido. A usuária estava em OU filha, fora do alcance.

**Correção:** refazer a delegação pelo assistente Delegar Controle, que propaga a herança para os objetos filhos.

**Lição:** permissão em OU precisa de herança para alcançar o conteúdo. Criar ACE programaticamente exige definir as flags de propagação.

