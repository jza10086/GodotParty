"""Bounded real-app multi-process checks; outputs and profiles stay under tmp/test/."""
import argparse
import pathlib
import shutil
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument('--count', type=int, choices=range(1, 9), default=2)
parser.add_argument('--scenario', choices=['probe', 'blank'], default='probe')
parser.add_argument('--spectator-host', action='store_true')
args = parser.parse_args()
if args.spectator_host and args.count < 2:
    parser.error('spectator host requires a participant')
base = pathlib.Path(__file__).resolve().parent
project = base.parents[2]
run = str(time.time_ns())
output = base / 'output' / run
output.mkdir(parents=True)
processes, logs, results = [], [], []
try:
    for index in range(args.count):
        log = (output / f'peer_{index}.log').open('w', encoding='utf-8')
        logs.append(log)
        command = [shutil.which('godot'), '--headless', '--path', str(project), '--log-file', str(output / f'engine_{index}.log'), '--script', 'res://tmp/test/framework_lab/network.gd', '--', f'--party-pack-dir={base / "packages"}', f'--party-profile=framework_lab_{run}_{index}', f'--lab-role={"host" if index == 0 else "client"}', f'--lab-count={args.count}', f'--lab-scenario={args.scenario}', f'--lab-delay={1.2 if index == args.count - 1 else 0.1}']
        if args.spectator_host:
            command.append('--lab-spectator-host')
        processes.append(subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW))
        if index == 0:
            time.sleep(1)
    results = [process.wait(timeout=55) for process in processes]
finally:
    for process in processes:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=5)
    for log in logs:
        log.close()
failed = False
for index, code in enumerate(results):
    text = (output / f'peer_{index}.log').read_text(encoding='utf-8')
    print(f'peer={index} exit={code}')
    relevant = [line for line in text.splitlines() if any(word in line for word in ['SCRIPT ERROR', 'ERROR:', 'LAB_', 'WARNING:'])]
    print('\n'.join(relevant))
    failed |= code != 0 or 'ERROR:' in text or 'SCRIPT ERROR' in text or 'LAB_NETWORK' not in text or 'failures=[]' not in text
print(f'Logs: {output}')
raise SystemExit(1 if failed else 0)
