# -*- coding: utf-8 -*-
"""本地数据库层验证 runner。
在没有 psql 的情况下用 psycopg2 执行全部 SQL 文件：
  setup 阶段（postgres 超级用户）：00_mock → migration → 03_grants → 01_seed
  验证阶段（web_user，RLS 生效）：02_verify_scenario
打印全部 PASS/FAIL notice；任何异常以非零退出。
"""
import os
import sys

import psycopg2

HOST = os.environ.get("PGHOST", "127.0.0.1")
PORT = int(os.environ.get("PGPORT", "55432"))
BASE = os.path.dirname(os.path.abspath(__file__))
MIGRATION = os.path.normpath(
    os.path.join(BASE, "..", "..", "supabase", "migrations", "001_initial_schema.sql")
)

SETUP_FILES = [
    os.path.join(BASE, "00_mock_supabase.sql"),
    MIGRATION,
    os.path.join(BASE, "03_grants.sql"),
    os.path.join(BASE, "01_seed_users.sql"),
]
VERIFY_FILE = os.path.join(BASE, "02_verify_scenario.sql")


def run_files(conn, files):
    for path in files:
        with open(path, encoding="utf-8") as f:
            sql = f.read()
        print(f"  executing {os.path.basename(path)} ...")
        with conn.cursor() as cur:
            cur.execute(sql)
    conn.commit()


def main():
    conn = psycopg2.connect(host=HOST, port=PORT, user="postgres", dbname="postgres")
    conn.autocommit = False
    try:
        print("[1/2] setup (superuser)")
        run_files(conn, SETUP_FILES)
    finally:
        conn.close()

    conn = psycopg2.connect(host=HOST, port=PORT, user="web_user", dbname="postgres")
    conn.autocommit = False
    failed = False
    try:
        print("[2/2] scenario (web_user, RLS enforced)")
        with open(VERIFY_FILE, encoding="utf-8") as f:
            sql = f.read()
        with conn.cursor() as cur:
            cur.execute(sql)
        conn.commit()
    except Exception as exc:  # noqa: BLE001
        failed = True
        print(f"SCENARIO FAILED: {exc}")
    finally:
        for notice in conn.notices:
            print(notice.strip())
        conn.close()

    if failed:
        sys.exit(1)
    print("LOCAL VERIFY: all good")
    sys.exit(0)


if __name__ == "__main__":
    main()
