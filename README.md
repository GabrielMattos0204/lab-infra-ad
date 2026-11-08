# Simulação de infraestrutura de identidade — cenário corporativo de energia

Laboratório de Active Directory Domain Services que reproduz, em ambiente controlado, a estrutura de identidade de uma empresa de grande porte com divisão entre área corporativa e operação industrial.

O cenário é inspirado no porte e na divisão de uma empresa do setor sucroenergético: matriz administrativa de um lado, unidade industrial de outro, com delegação de suporte por escopo. Não é reprodução do ambiente real de nenhuma empresa.

## Objetivo

Praticar, com automação e documentação, as rotinas de administração de identidade que sustentam operação de TI: estrutura organizacional, provisionamento em lote, menor privilégio, política de grupo e monitoramento de saúde do domínio.

## Arquitetura lógica

```
lab.local
└── LAB
    ├── Corporativo
    │   └── Usuarios
    │       ├── TI
    │       └── Financeiro
    ├── Costa_Pinto
    │   └── Usuarios
    │       └── Operacao
    ├── Grupos_Seguranca
    └── Computadores
```

Grupos globais: `GG_HelpDesk`, `GG_TI`, `GG_Financeiro`, `GG_Operacao`.

## O que o projeto entrega

- **Provisionamento parametrizado** de OUs, grupos e usuários a partir de CSV, simulando carga vinda do RH
- **Idempotência**: reexecutar não duplica objeto, e cada ação registrada como `OK` ou `SKIP`
- **Log de execução** com data, hora e nível
- **Delegação de controle** de redefinição de senha para o grupo de help desk, nas duas OUs de usuários, sem conceder Domain Admin
- **Política de grupo** com mapeamento de unidade de rede e bloqueio do Painel de Controle, validada com usuária comum e `gpresult`
- **Monitoramento de saúde** do domínio: disponibilidade de DC, serviços críticos, contas bloqueadas, espaço em disco e erros recentes
- **Agendamento** do monitor a cada 15 minutos, com código de saída 1 em caso de alerta

## Estrutura

```
data/            ous.csv, usuarios.csv
scripts/         01-provisionar.ps1
monitoramento/   checar-dominio.ps1
docs/            etapas e problemas.md
imagens/         evidências
logs/            saída de execução (ignorado no Git)
```

## Pré-requisitos

- Windows Server 2022 com função AD DS instalada e servidor promovido
- PowerShell 5.1 ou superior, execução como Administrador
- Módulo ActiveDirectory

## Como executar

```
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
cd scripts
.\01-provisionar.ps1
```

Para o monitor:

```
cd monitoramento
.\checar-dominio.ps1
```

Agendamento:

```
$acao = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -Command `"& 'C:\lab\lab-infra-ad\monitoramento\checar-dominio.ps1' *> 'C:\lab\lab-infra-ad\logs\task-out.txt'`""
$gatilho = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 15)
Register-ScheduledTask -TaskName "MONITOR-DOMINIO" -Action $acao -Trigger $gatilho -User "LAB\Administrator" -RunLevel Highest
```

## Decisões de projeto

**Grupo em vez de permissão direta no usuário.** Toda permissão passa por grupo global, para que a mudança de pessoa não exija reconfigurar ACL.

**Delegação em vez de Domain Admin.** O help desk redefine senha apenas no escopo das OUs de usuários. Menor privilégio aplicado de fato.

**CSV como origem.** A criação de usuários parte de arquivo, não de comando avulso, aproximando o script do fluxo real de admissão.

**Validação antes de criar.** Cada função consulta o objeto antes de criá-lo, o que garante idempotência.

**Log em toda ação.** Sem registro não há auditoria.

## Evidências

Em `imagens/`: primeira execução com `OK`, segunda com `SKIP`, ACL com a delegação, `gpresult` confirmando a GPO aplicada, unidade mapeada, Painel de Controle bloqueado e alerta de conta bloqueada no monitor.

## Limites conhecidos

- Um único controlador de domínio, sem replicação
- GPO criada manualmente, não pelo script
- Teste de logon feito no próprio DC, sem máquina cliente dedicada
- Delegação validada funcionalmente: usuário de help desk redefiniu senha dentro do escopo e recebeu acesso  negado fora dele
- Sem PKI, sem backup real, sem segundo DC
- Licença de avaliação de 180 dias

## Problemas encontrados

Ver [docs/problemas.md](docs/problemas.md): onze ocorrências reais com sintoma, causa e correção.

## Autor

Gabriel Mattos — estudante de Análise e Desenvolvimento de Sistemas, Limeira/SP.
[LinkedIn](https://www.linkedin.com/in/gabriel-mattos-766489422) · [GitHub](https://github.com/GabrielMattos0204)