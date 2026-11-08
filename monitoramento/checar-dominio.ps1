<#
.SYNOPSIS
Verifica saude do dominio e registra resultado em log.
Retorna codigo 1 quando encontra alerta.
#>
[CmdletBinding()]
param(
    [string]$Dominio = "lab.local",
    [string]$ArquivoLog = (Join-Path $PSScriptRoot "..\logs\monitoramento.log")
)

function Write-Log {
    param([string]$Mensagem, [string]$Nivel = "INFO")
    $linha = "{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Nivel, $Mensagem
    $linha | Out-File -FilePath $ArquivoLog -Append -Encoding utf8
    Write-Host $linha
}

$alertas = 0

Write-Log "--- Inicio da checagem ---"

# Controladores de dominio
try {
    $dcs = Get-ADDomainController -Filter *
    foreach ($dc in $dcs) {
        if (Test-Connection -ComputerName $dc.HostName -Count 1 -Quiet) {
            Write-Log "DC respondendo: $($dc.HostName)" "OK"
        } else {
            Write-Log "DC sem resposta: $($dc.HostName)" "ALERTA"; $alertas++
        }
    }
} catch { Write-Log "Falha ao listar DCs: $($_.Exception.Message)" "ALERTA"; $alertas++ }

# Servicos criticos
foreach ($svc in @("NTDS","DNS","Netlogon")) {
    $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($null -eq $s) { Write-Log "Servico ausente: $svc" "ALERTA"; $alertas++ }
    elseif ($s.Status -ne "Running") { Write-Log "Servico parado: $svc" "ALERTA"; $alertas++ }
    else { Write-Log "Servico ativo: $svc" "OK" }
}

# Contas bloqueadas
try {
    $bloqueadas = @(Search-ADAccount -LockedOut -UsersOnly)
    if ($bloqueadas) {
        Write-Log "Contas bloqueadas: $($bloqueadas.Count)" "ALERTA"; $alertas++
        $bloqueadas | ForEach-Object { Write-Log "  bloqueada: $($_.SamAccountName)" "ALERTA" }
    } else { Write-Log "Nenhuma conta bloqueada" "OK" }
} catch { Write-Log "Falha ao checar bloqueios" "ALERTA"; $alertas++ }

# Disco
$disco = Get-PSDrive C
$livreGB = [math]::Round($disco.Free / 1GB, 1)
if ($livreGB -lt 10) { Write-Log "Disco C com $livreGB GB livres" "ALERTA"; $alertas++ }
else { Write-Log "Disco C com $livreGB GB livres" "OK" }

# Erros recentes
$erros = Get-EventLog -LogName System -EntryType Error -Newest 5 -ErrorAction SilentlyContinue
if ($erros) { Write-Log "Erros recentes no log System: $($erros.Count)" "ALERTA"; $alertas++ }
else { Write-Log "Sem erros recentes no log System" "OK" }

Write-Log "--- Fim da checagem: $alertas alerta(s) ---"
if ($alertas -gt 0) { exit 1 }