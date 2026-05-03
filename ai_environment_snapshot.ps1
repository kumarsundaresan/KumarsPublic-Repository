# AI Environment Snapshot Collector
# Runs on Windows PowerShell and captures:
# - Windows tools and PATH
# - Claude / Antigravity / Git / Python / Node
# - WSL status
# - Ubuntu environment details through WSL
# - PostgreSQL / MongoDB / Python / Node / common project folders inside WSL
# Output: timestamped text file in current folder

$ErrorActionPreference = "SilentlyContinue"

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outFile = Join-Path (Get-Location) "ai_environment_snapshot_$timestamp.txt"

function Add-Section($title) {
    Add-Content -Path $outFile -Value ""
    Add-Content -Path $outFile -Value ("=" * 90)
    Add-Content -Path $outFile -Value $title
    Add-Content -Path $outFile -Value ("=" * 90)
}

function Add-Line($text) {
    Add-Content -Path $outFile -Value $text
}

function Add-Cmd($label, $cmd) {
    Add-Line ""
    Add-Line ("--- " + $label + " ---")
    Add-Line ("$ " + $cmd)
    try {
        $result = Invoke-Expression $cmd | Out-String
        if ([string]::IsNullOrWhiteSpace($result)) {
            Add-Line "[no output]"
        } else {
            Add-Content -Path $outFile -Value $result.TrimEnd()
        }
    } catch {
        Add-Line ("[error] " + $_.Exception.Message)
    }
}

# Start fresh file
"AI SOFTWARE ENVIRONMENT SNAPSHOT" | Set-Content -Path $outFile
"Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')" | Add-Content -Path $outFile
"Computer: $env:COMPUTERNAME" | Add-Content -Path $outFile
"Windows User: $env:USERNAME" | Add-Content -Path $outFile
"Current Folder: $(Get-Location)" | Add-Content -Path $outFile

Add-Section "WINDOWS BASIC SYSTEM"
Add-Cmd "PowerShell version" '$PSVersionTable | Out-String'
Add-Cmd "Windows OS" 'Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, BuildNumber, OSArchitecture | Format-List | Out-String'
Add-Cmd "Environment summary" 'Get-ChildItem Env: | Sort-Object Name | Out-String'

Add-Section "WINDOWS PATH AND KEY LOCATIONS"
Add-Line "UserProfile: $env:USERPROFILE"
Add-Line "HomeDrive: $env:HOMEDRIVE"
Add-Line "HomePath : $env:HOMEPATH"
Add-Line "APPDATA  : $env:APPDATA"
Add-Line "LOCALAPPDATA: $env:LOCALAPPDATA"
Add-Line ""
Add-Line "User PATH:"
Add-Content -Path $outFile -Value ([Environment]::GetEnvironmentVariable("Path","User"))
Add-Line ""
Add-Line "Machine PATH:"
Add-Content -Path $outFile -Value ([Environment]::GetEnvironmentVariable("Path","Machine"))
Add-Line ""
Add-Line "Effective PATH:"
Add-Content -Path $outFile -Value $env:Path

Add-Section "WINDOWS TOOLING"
Add-Cmd "where python" 'where.exe python'
Add-Cmd "where py" 'where.exe py'
Add-Cmd "where pip" 'where.exe pip'
Add-Cmd "where node" 'where.exe node'
Add-Cmd "where npm" 'where.exe npm'
Add-Cmd "where npx" 'where.exe npx'
Add-Cmd "where git" 'where.exe git'
Add-Cmd "where claude" 'where.exe claude'
Add-Cmd "where antigravity" 'where.exe antigravity'
Add-Cmd "python version" 'python --version'
Add-Cmd "py launcher versions" 'py -0p'
Add-Cmd "pip version" 'pip --version'
Add-Cmd "node version" 'node -v'
Add-Cmd "npm version" 'npm -v'
Add-Cmd "npx version" 'npx -v'
Add-Cmd "git version" 'git --version'
Add-Cmd "claude version" 'claude --version'
Add-Cmd "claude help first line" 'claude --help | Select-Object -First 20'
Add-Cmd "Antigravity package folder" 'Get-ChildItem "$env:LOCALAPPDATA\Programs" -Directory | Where-Object { $_.Name -match "Antigravity" } | Select-Object FullName | Format-Table -AutoSize | Out-String'
Add-Cmd "Claude native binary folder" 'Get-ChildItem "$env:USERPROFILE\.local\bin" -ErrorAction SilentlyContinue | Format-Table Name, FullName -AutoSize | Out-String'
Add-Cmd "VS Code bin folder" 'Get-ChildItem "$env:LOCALAPPDATA\Programs\Microsoft VS Code" -ErrorAction SilentlyContinue | Select-Object FullName | Format-Table -AutoSize | Out-String'

Add-Section "WSL FROM WINDOWS"
Add-Cmd "WSL status" 'wsl --status'
Add-Cmd "WSL distros" 'wsl -l -v'

# Build bash payload for Ubuntu
$bashPayload = @'
set +e
echo "WSL_USER=$(whoami)"
echo "WSL_HOST=$(hostname)"
echo "WSL_HOME=$HOME"
echo "WSL_PWD=$(pwd)"
echo ""

echo "### UBUNTU / KERNEL ###"
uname -a
echo ""
if command -v lsb_release >/dev/null 2>&1; then
  lsb_release -a 2>/dev/null
else
  cat /etc/os-release 2>/dev/null
fi
echo ""

echo "### ENVIRONMENT VARIABLES ###"
env | sort
echo ""

echo "### PATH ###"
echo "$PATH"
echo ""

echo "### COMMON LOCATIONS ###"
printf "HOME listing:\n"
ls -la "$HOME" 2>/dev/null
echo ""
for d in "$HOME/scripts" "$HOME/smartomation" "$HOME/.nvm" "$HOME/.venvs" "$HOME/.local/bin" "/usr/bin" "/usr/local/bin"; do
  echo "--- $d ---"
  ls -la "$d" 2>/dev/null || echo "[missing]"
  echo ""
done

echo "### PYTHON ###"
command -v python || true
command -v python3 || true
command -v pip || true
command -v pip3 || true
python --version 2>/dev/null || true
python3 --version 2>/dev/null || true
pip --version 2>/dev/null || true
pip3 --version 2>/dev/null || true
echo ""
python3 - <<'PYINFO'
import os, sys, site, platform
print("sys.executable =", sys.executable)
print("sys.version =", sys.version.replace("\n"," "))
print("sys.prefix =", sys.prefix)
print("platform =", platform.platform())
try:
    print("site.getsitepackages =", site.getsitepackages())
except Exception as e:
    print("site.getsitepackages error =", e)
print("cwd =", os.getcwd())
print("home =", os.path.expanduser("~"))
PYINFO
echo ""

echo "### VIRTUAL ENVS / CONDA ###"
for d in "$HOME/venv" "$HOME/.venv" "$HOME/scripts/venv" "$HOME/miniconda3" "$HOME/anaconda3"; do
  echo "--- $d ---"
  ls -la "$d" 2>/dev/null || echo "[missing]"
done
echo ""

echo "### NODE / NVM ###"
command -v node || true
command -v npm || true
command -v npx || true
node -v 2>/dev/null || true
npm -v 2>/dev/null || true
npx -v 2>/dev/null || true
if [ -s "$HOME/.nvm/nvm.sh" ]; then
  echo "NVM detected at $HOME/.nvm"
  . "$HOME/.nvm/nvm.sh"
  echo "nvm version:"
  nvm --version 2>/dev/null || true
  echo "nvm current:"
  nvm current 2>/dev/null || true
  echo "nvm ls:"
  nvm ls 2>/dev/null || true
else
  echo "NVM not found"
fi
echo ""

echo "### DATABASES ###"
echo "PostgreSQL service status:"
service postgresql status 2>&1 || true
echo ""
echo "MongoDB service status:"
service mongod status 2>&1 || true
echo ""
echo "Listening ports 5432 / 27017:"
ss -ltnp 2>/dev/null | egrep "5432|27017" || true
echo ""
echo "pg_isready:"
pg_isready -h 127.0.0.1 -p 5432 2>&1 || true
echo ""
echo "postgres binaries:"
command -v psql || true
command -v pg_isready || true
psql --version 2>/dev/null || true
echo ""
echo "mongo binaries:"
command -v mongosh || true
command -v mongod || true
mongosh --version 2>/dev/null || true
mongod --version 2>/dev/null | head -n 5 || true
echo ""

echo "### PROJECT / DEV TOOLS ###"
for c in git code claude antigravity docker java javac; do
  echo "--- $c ---"
  command -v "$c" 2>/dev/null || echo "[not found]"
done
echo ""
git --version 2>/dev/null || true

echo ""
echo "### POSTGRES DATA / CONFIG CANDIDATES ###"
find /etc/postgresql -maxdepth 3 -type f 2>/dev/null | sort || true
echo ""
find /var/lib/postgresql -maxdepth 3 -type d 2>/dev/null | sort | head -n 50 || true
echo ""

echo "### MONGO DATA / CONFIG CANDIDATES ###"
for f in /etc/mongod.conf /var/log/mongodb /var/lib/mongodb; do
  echo "--- $f ---"
  ls -la "$f" 2>/dev/null || echo "[missing]"
done
echo ""

echo "### LAST RELEVANT SHELL RC FILES ###"
for f in "$HOME/.bashrc" "$HOME/.profile" "$HOME/.zshrc"; do
  echo "--- $f ---"
  tail -n 100 "$f" 2>/dev/null || echo "[missing]"
  echo ""
done
'@

$encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($bashPayload))
Add-Cmd "WSL Ubuntu environment capture" "wsl -d Ubuntu bash -lc `"eval \$(echo $encoded | base64 -d 2>/dev/null)`""

Add-Section "SUMMARY HINTS"
Add-Line "Use this file as an uploaded context document when asking setup or troubleshooting questions."
Add-Line "Suggested prompt:"
Add-Line "I am uploading my AI environment snapshot. Use it as the primary context and tell me what is wrong / what to install / how to fix <issue>."

Write-Host "Created: $outFile"
