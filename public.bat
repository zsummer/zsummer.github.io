set writer="%~dp0"
echo %writer%
git pull
cd ../public
git pull
cd %writer%
hexo g
pause