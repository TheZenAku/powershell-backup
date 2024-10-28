<#
By: Rafael "Zen-Aku"
Contato: rafaelrodrigues-2017@hotmail.com

v1.2.0
Foi adicionado uma opção onde você agora pode indicar quais diretórios deseja ignorar;
Foi modificado a maneira como o log é salvo, agora ele possui data e hora no nome do arquivo "Log_dd-MM-yy_HH-mm.log";
Adicionado o argumento "/MT:64" na operação robocopy para otimizar a cópia dos arquivos;
Adicionado suporte ao encoding de saída para UTF-8;

v1.0.0
Este script realiza a cópia dos arquivos nos diretórios informados utilizando o robocopy e por fim, envia um aquivo de log para seu e-mail
ao final da operação informando se tudo ocorreu bem. Você também tem a opção de compactar os arquivos em formato .zip caso ache necessário,
e neste caso, você poderá definir o número de cópias que você deseja armazenar alterando a variável $limiteCopias para a quantidade desejada.
Caso a variável $deveZipar esteja como falsa, o script ignora o limite de cópias estabelecidas na variável $limiteCopias.
#>

$dirsParaBackup = @("") # Lista de diretórios para backup

$dirsParaIgnorar = @("") # Lista de diretórios para ignorar durante a cópia (pode ser deixado em branco se necessário).

$dirDestino = "" # Destino do backup

$deveZipar = $true # Deve zipar os arquivos de backup? "$false" para desativar

$emailRemetente = "" # E-mail remetente

$emailDestinatario = "" # E-mail destinatário

$senhaEmail = "" # Você deve utilizar sua senha de aplicativo da google aqui!

$limiteCopias = 1 # Limite de cópias de backup armazenadas (se aplica somente quando "$deveZipar = $true")


########################### NÃO ALTERE NENHUMA LINHA ABAIXO ###########################
chcp 65001 | Out-Null

# Criando o diretório de destino, se necessário
if (!(Test-Path -Path $dirDestino)) {
    New-Item -Path $dirDestino -ItemType Directory -Force | Out-Null
}

# Compactar um diretório
function ZiparDiretorio {
    param(
        [string]$dirPath,
        [string]$zipFilePath
    )

    if (!(Test-Path -Path $zipFilePath)) {
        Write-Output "Criando arquivo zip $zipFilePath"
        Compress-Archive -Path $dirPath -DestinationPath $zipFilePath
    } else {
        Write-Output "Arquivo zip $zipFilePath já existe, adicionando conteúdo"
        Compress-Archive -Path $dirPath -Update -DestinationPath $zipFilePath
    }
}

# Enviar e-mail com o arquivo de log anexado
function EnviarEmail {
    param(
        [string]$remetente,
        [string]$destinatario,
        [string]$senha,
        [string]$assunto,
        [string]$corpo,
        [string]$anexo
    )

    $EmailFrom = $remetente
    $EmailTo = $destinatario
    $Subject = $assunto
    $Body = $corpo

    $SMTPServer = "smtp.gmail.com"
    $SMTPClient = New-Object Net.Mail.SmtpClient($SmtpServer, 587)
    $SMTPClient.EnableSsl = $true
    $SMTPClient.Credentials = New-Object System.Net.NetworkCredential($EmailFrom, $senha)
    
    $MailMessage = New-Object Net.Mail.MailMessage
    $MailMessage.From = $EmailFrom
    $MailMessage.To.Add($EmailTo)
    $MailMessage.Subject = $Subject
    $MailMessage.Body = $Body
    
    $Attachment = New-Object Net.Mail.Attachment($anexo, "text/plain; charset=utf-8")
    $MailMessage.Attachments.Add($Attachment)
    
    $SMTPClient.Send($MailMessage)
    $Attachment.Dispose()
}

$logDate = Get-Date -Format "dd-MM-yy_HH-mm" # Obtém a data atual formatada
$prefixoLog = "Log_" # Define o prefixo do log
$logName = $prefixoLog + $logDate # Combina o prefixo com a data

# Copiando os arquivos para os diretórios de backup usando Robocopy e gerando o log
$dirsParaBackup | ForEach-Object {
    $dir = $_
    $dirNome = Split-Path $dir -Leaf
    $dirDestinoPath = Join-Path -Path $dirDestino -ChildPath $dirNome

    # Criando o diretório de destino para este backup, se necessário
    if (!(Test-Path -Path $dirDestinoPath)) {
        New-Item -Path $dirDestinoPath -ItemType Directory -Force | Out-Null
    }

    # Executando o Robocopy com diretórios a serem ignorados
    robocopy $dir $dirDestinoPath /MT:64 /E /Z /R:5 /W:5 /UNICODE /LOG+:$dirDestino\$logName.log /XD $dirsParaIgnorar
}

# Verificando se $deveZipar é verdadeiro antes de aplicar a regra do limite de cópias
if ($deveZipar) {
    # Verificando o número de arquivos no diretório de destino
    $arquivosBackup = Get-ChildItem -Path $dirDestino -File -Filter "*.zip"
    $copias = $arquivosBackup.Count

    # Remova o arquivo mais antigo, se necessário
    if ($copias -gt $limiteCopias) {
        $arquivosMaisAntigos = $arquivosBackup | Sort-Object CreationTime | Select-Object -First ($copias - $limiteCopias)
        
        $arquivosMaisAntigos | ForEach-Object {
            Remove-Item -Path $_.FullName -Force
        }
    }

    # Compactando diretórios, se necessário
    $dataHora = Get-Date -Format "ddMMyy_HHmm"
    $zipFileName = "Backup_$dataHora.zip"
    $zipFilePath = Join-Path -Path $dirDestino -ChildPath $zipFileName

    $dirsParaBackup | ForEach-Object {
        $dir = $_
        $dirNome = Split-Path $dir -Leaf
        $dirDestinoPath = Join-Path -Path $dirDestino -ChildPath $dirNome
        ZiparDiretorio -dirPath $dirDestinoPath -zipFilePath $zipFilePath
    }

    # Removendo diretórios de backup após a compactação
    $dirsParaBackup | ForEach-Object {
        $dir = $_
        $dirNome = Split-Path $dir -Leaf
        $dirDestinoPath = Join-Path -Path $dirDestino -ChildPath $dirNome
        Remove-Item -Path $dirDestinoPath -Recurse -Force
    }
}

$EmailHora = Get-Date -Format "ddMMyy_HHmm"

# Enviando o e-mail com o arquivo de log anexado
$assuntoEmail = "Operação concluída"
$corpoEmail = "Operação concluída em $EmailHora, verifique o LOG pra mais detalhes."
$arquivoLog = Join-Path -Path $dirDestino -ChildPath "$logName.log"
EnviarEmail -remetente $emailRemetente -destinatario $emailDestinatario -senha $senhaEmail -assunto $assuntoEmail -corpo $corpoEmail -anexo $arquivoLog