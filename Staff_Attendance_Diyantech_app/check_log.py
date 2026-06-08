import subprocess
result = subprocess.run(["git", "log", "-p", "--", "lib/features/attendance/scanner_screen.dart"], capture_output=True, text=True)
lines = result.stdout.split('\n')
for i, line in enumerate(lines):
    if "minDistance <" in line and (line.startswith("-") or line.startswith("+")):
        print(line)
