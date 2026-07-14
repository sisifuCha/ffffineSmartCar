@echo off
cd /d %~dp0
if not exist config.yaml copy config.yaml.example config.yaml
pip install -r requirements.txt
python main.py
pause
