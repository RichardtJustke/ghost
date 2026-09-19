#!/usr/bin/env python3
import sqlite3
import json
import os
import argparse
from datetime import date, timedelta

XP_PER_LEVEL = 10


def get_conn(db_dir):
    os.makedirs(db_dir, exist_ok=True)
    conn = sqlite3.connect(os.path.join(db_dir, "habits.db"))
    conn.execute(
        "CREATE TABLE IF NOT EXISTS habit_log ("
        "log_date TEXT, habit_id TEXT, done INTEGER NOT NULL, "
        "PRIMARY KEY (log_date, habit_id))"
    )
    conn.commit()
    return conn


def is_done(c, log_date, habit_id):
    row = c.execute(
        "SELECT done FROM habit_log WHERE log_date = ? AND habit_id = ?",
        (log_date, habit_id),
    ).fetchone()
    return bool(row and row[0])


def compute_streak(c, habit_id, target_date):
    streak = 0
    cur = target_date if is_done(c, target_date.isoformat(), habit_id) else target_date - timedelta(days=1)
    while is_done(c, cur.isoformat(), habit_id):
        streak += 1
        cur -= timedelta(days=1)
    return streak


def build_status(conn, habit_ids, target_date):
    c = conn.cursor()

    habits = []
    for hid in habit_ids:
        habits.append({
            "id": hid,
            "done": is_done(c, target_date.isoformat(), hid),
            "streak": compute_streak(c, hid, target_date),
        })

    total_xp = c.execute("SELECT COUNT(*) FROM habit_log WHERE done = 1").fetchone()[0] or 0
    level = total_xp // XP_PER_LEVEL + 1
    xp_into_level = total_xp % XP_PER_LEVEL

    heatmap = []
    habit_count = max(1, len(habit_ids))
    for i in range(29, -1, -1):
        d = target_date - timedelta(days=i)
        row = c.execute(
            "SELECT COUNT(*) FROM habit_log WHERE log_date = ? AND done = 1", (d.isoformat(),)
        ).fetchone()
        done_count = row[0] or 0
        heatmap.append({"date": d.isoformat(), "ratio": done_count / habit_count})

    return {
        "habits": habits,
        "xp": total_xp,
        "level": level,
        "xpIntoLevel": xp_into_level,
        "xpPerLevel": XP_PER_LEVEL,
        "heatmap": heatmap,
    }


def parse_habits(raw):
    return [h for h in raw.split(",") if h]


def cmd_status(args):
    conn = get_conn(args.db_dir)
    try:
        target = date.fromisoformat(args.date)
    except ValueError:
        target = date.today()
    print(json.dumps(build_status(conn, parse_habits(args.habits), target)))


def cmd_toggle(args):
    conn = get_conn(args.db_dir)
    try:
        target = date.fromisoformat(args.date)
    except ValueError:
        target = date.today()

    c = conn.cursor()
    currently_done = is_done(c, target.isoformat(), args.habit_id)
    new_value = 0 if currently_done else 1
    c.execute(
        "INSERT INTO habit_log (log_date, habit_id, done) VALUES (?, ?, ?) "
        "ON CONFLICT(log_date, habit_id) DO UPDATE SET done = excluded.done",
        (target.isoformat(), args.habit_id, new_value),
    )
    conn.commit()

    print(json.dumps(build_status(conn, parse_habits(args.habits), target)))


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_status = sub.add_parser("status")
    p_status.add_argument("date")
    p_status.add_argument("--habits", required=True)
    p_status.add_argument("--db-dir", required=True)

    p_toggle = sub.add_parser("toggle")
    p_toggle.add_argument("date")
    p_toggle.add_argument("habit_id")
    p_toggle.add_argument("--habits", required=True)
    p_toggle.add_argument("--db-dir", required=True)

    args = parser.parse_args()
    if args.cmd == "status":
        cmd_status(args)
    elif args.cmd == "toggle":
        cmd_toggle(args)


if __name__ == "__main__":
    main()
