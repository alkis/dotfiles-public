export WSL=$(grep -q Microsoft /proc/version && echo 1 || echo 0)
export PATH=$HOME/bin:$PATH
export EDITOR=nano

if [[ $WSL == 1 ]]; then
  export DISPLAY=:0
  export WIN_TMPDIR=$(wslpath ${$(/mnt/c/Windows/System32/cmd.exe /c "echo %TMP%")%$'\r'})
fi

umask 0002
ulimit -c unlimited
