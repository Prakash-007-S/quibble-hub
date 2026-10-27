import os
import sys
import time
import socket
import subprocess
from pathlib import Path

PG_BIN_DIR = Path(r"C:\Program Files\PostgreSQL\18\bin")
if not PG_BIN_DIR.exists():
    PG_BIN_DIR = Path(r"C:\Program Files\PostgreSQL\15\bin")

PROJECT_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = PROJECT_DIR / ".postgres_data"
PORT = int(os.environ.get("POSTGRES_PORT", 5434))
DB_NAME = os.environ.get("POSTGRES_DB", "complaint_db")
USER = os.environ.get("POSTGRES_USER", "postgres")

def is_port_in_use(port: int, host: str = "127.0.0.1") -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.settimeout(1.0)
        return s.connect_ex((host, port)) == 0

def init_db():
    if not DATA_DIR.exists():
        print(f"[*] Initializing PostgreSQL cluster in {DATA_DIR}...")
        initdb_exe = PG_BIN_DIR / "initdb.exe"
        cmd = [
            str(initdb_exe),
            "-D", str(DATA_DIR),
            "-U", USER,
            "-A", "trust",
            "--no-locale",
            "-E", "UTF8"
        ]
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode != 0:
            print(f"[!] initdb failed:\n{res.stderr}")
            sys.exit(1)
        print("[+] Cluster initialized successfully.")

def start_server():
    if is_port_in_use(PORT):
        print(f"[+] PostgreSQL is already listening on port {PORT}.")
        return None

    print(f"[*] Starting PostgreSQL on port {PORT}...")
    postgres_exe = PG_BIN_DIR / "postgres.exe"
    log_file = DATA_DIR / "server.log"
    log_fp = open(log_file, "a")

    proc = subprocess.Popen(
        [str(postgres_exe), "-D", str(DATA_DIR), "-p", str(PORT)],
        stdout=log_fp,
        stderr=subprocess.STDOUT
    )

    for _ in range(30):
        time.sleep(0.5)
        if is_port_in_use(PORT):
            print(f"[+] PostgreSQL server started and ready on port {PORT}.")
            return proc
    print("[!] Timed out waiting for PostgreSQL server.")
    return proc

def ensure_database():
    try:
        import psycopg2
        from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT
        conn = psycopg2.connect(dbname="postgres", user=USER, host="127.0.0.1", port=PORT)
        conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
        cur = conn.cursor()
        cur.execute("SELECT 1 FROM pg_database WHERE datname = %s", (DB_NAME,))
        exists = cur.fetchone()
        if not exists:
            print(f"[*] Creating database '{DB_NAME}'...")
            cur.execute(f'CREATE DATABASE "{DB_NAME}"')
            print(f"[+] Database '{DB_NAME}' created.")
        else:
            print(f"[+] Database '{DB_NAME}' exists.")
        cur.close()
        conn.close()
    except Exception as e:
        print(f"[!] Error ensuring database: {e}")

if __name__ == "__main__":
    init_db()
    proc = start_server()
    ensure_database()
    if "--daemon" in sys.argv:
        print("[*] Running in background / daemon mode. Keeping process alive...")
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            if proc:
                proc.terminate()
