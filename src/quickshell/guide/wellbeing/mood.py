#!/usr/bin/env python3
import sqlite3
import json
import os
import argparse
from datetime import date, timedelta


def get_conn(db_dir):
    os.makedirs(db_dir, exist_ok=True)
    conn = sqlite3.connect(os.path.join(db_dir, "mood.db"))
    conn.execute("CREATE TABLE IF NOT EXISTS mood_log (log_date TEXT PRIMARY KEY, value INTEGER NOT NULL)")
    conn.commit()
    return conn


def cmd_set(args):
    conn = get_conn(args.db_dir)
    conn.execute(
        "INSERT INTO mood_log (log_date, value) VALUES (?, ?) "
        "ON CONFLICT(log_date) DO UPDATE SET value = excluded.value",
        (args.date, args.value),
    )
    conn.commit()
    print(json.dumps({"ok": True}))


def cmd_week(args):
    conn = get_conn(args.db_dir)
    c = conn.cursor()

    try:
        target = date.fromisoformat(args.date)
    except ValueError:
        target = date.today()

    monday = target - timedelta(days=target.weekday())
    week = []
    for i in range(7):
        d = monday + timedelta(days=i)
        row = c.execute("SELECT value FROM mood_log WHERE log_date = ?", (d.isoformat(),)).fetchone()
        week.append({"date": d.isoformat(), "value": row[0] if row else 0})

    today_row = c.execute("SELECT value FROM mood_log WHERE log_date = ?", (target.isoformat(),)).fetchone()
    print(json.dumps({"week": week, "today": today_row[0] if today_row else 0}))


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_set = sub.add_parser("set")
    p_set.add_argument("date")
    p_set.add_argument("value", type=int)
    p_set.add_argument("--db-dir", required=True)

    p_week = sub.add_parser("week")
    p_week.add_argument("date")
    p_week.add_argument("--db-dir", required=True)

    args = parser.parse_args()
    if args.cmd == "set":
        if args.value < 1 or args.value > 5:
            raise SystemExit("value must be between 1 and 5")
        cmd_set(args)
    elif args.cmd == "week":
        cmd_week(args)


if __name__ == "__main__":
    main()
