set writer="%~dp0"
echo %writer%
git pull
cd ../zsummer.github.io
git pull
cd %writer%
hexo g
pause