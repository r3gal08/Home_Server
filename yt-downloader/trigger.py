#!/usr/bin/env python3
import os
import socket
import subprocess
import threading
import time
from datetime import datetime

PORT = int(os.environ.get("TRIGGER_PORT", 9998))
CONFIG = os.environ.get("YT_DLP_CONF", "/config/yt-dlp.conf")
PLAYLISTS = os.environ.get("PLAYLISTS", "/config/playlists.txt")
SCHEDULE_HOUR = int(os.environ.get("SCHEDULE_HOUR", 0))      # 0 = 12 AM (midnight)
SCHEDULE_MINUTE = int(os.environ.get("SCHEDULE_MINUTE", 0))
# Expected trigger token (ignores all other packets / smart home broadcasts)
TRIGGER_TOKEN = os.environ.get("TRIGGER_TOKEN", "download").strip()

# Thread lock to prevent concurrent yt-dlp executions
download_lock = threading.Lock()

def run_download(source="UDP"):
    """Executes yt-dlp. If a download is already in progress, ignores duplicate triggers."""
    if not download_lock.acquire(blocking=False):
        print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] [{source}] Download already in progress. Ignoring duplicate trigger.")
        return

    try:
        print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] [{source}] Starting yt-dlp...")
        cmd = [
            "yt-dlp",
            "--config-locations", CONFIG,
            "-a", PLAYLISTS
        ]
        result = subprocess.run(cmd)
        print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] [{source}] yt-dlp finished with exit code {result.returncode}")
    except Exception as e:
        print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] [{source}] Error executing yt-dlp: {e}")
    finally:
        download_lock.release()

def daily_scheduler():
    """Background scheduler that triggers downloads at the specified time (default 12:00 AM)."""
    last_run_date = None
    print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] [Schedule] Daily scheduler active: triggers every day at {SCHEDULE_HOUR:02d}:{SCHEDULE_MINUTE:02d}")

    while True:
        now = datetime.now()
        if now.hour == SCHEDULE_HOUR and now.minute == SCHEDULE_MINUTE and last_run_date != now.date():
            last_run_date = now.date()
            print(f"[{now.strftime('%Y-%m-%d %H:%M:%S')}] [Schedule] Daily 12:00 AM trigger fired.")
            threading.Thread(target=run_download, args=("Schedule",), daemon=True).start()
        time.sleep(30)

def main():
    # Start the daily cron/scheduler thread
    threading.Thread(target=daily_scheduler, daemon=True).start()

    # Start the UDP listener
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(("0.0.0.0", PORT))
    print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] [UDP] Listener active on 0.0.0.0:{PORT}")
    print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] [UDP] Expected trigger token: '{TRIGGER_TOKEN}'")
    print(f"Trigger command example: echo '{TRIGGER_TOKEN}' | nc -u -w1 <IP> {PORT}")

    while True:
        data, addr = sock.recvfrom(1024)
        msg = data.decode("utf-8", errors="ignore").strip()
        
        # Verify packet content matches expected trigger token
        if msg == TRIGGER_TOKEN:
            print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] [UDP] Valid trigger token received from {addr[0]}:{addr[1]}")
            threading.Thread(target=run_download, args=("UDP",), daemon=True).start()
        else:
            # Drop stray broadcasts, scans, or unexpected payloads
            print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] [UDP] Ignored packet from {addr[0]}:{addr[1]} (payload: {repr(msg)})")

if __name__ == "__main__":
    main()
