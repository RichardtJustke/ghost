#!/usr/bin/env python3
import re
import sqlite3
import json
import os
import argparse
from datetime import date, timedelta

XP_PER_LEVEL = 10

BUILTIN_DEFAULTS = [
    # (id, name, category, sort_order)
    ("coding", "coding", "", 0),
    ("water", "drink water", "", 1),
    ("read", "read", "", 2),
]


def get_conn(db_dir):
    os.makedirs(db_dir, exist_ok=True)
    conn = sqlite3.connect(os.path.join(db_dir, "habits.db"))
    conn.execute(
        "CREATE TABLE IF NOT EXISTS habit_log ("
        "log_date TEXT, habit_id TEXT, done INTEGER NOT NULL, "
        "PRIMARY KEY (log_date, habit_id))"
    )
    conn.execute(
        "CREATE TABLE IF NOT EXISTS habit_def ("
        "id TEXT PRIMARY KEY, name TEXT NOT NULL, category TEXT NOT NULL DEFAULT '', "
        "builtin INTEGER NOT NULL DEFAULT 0, archived INTEGER NOT NULL DEFAULT 0, "
        "sort_order INTEGER NOT NULL DEFAULT 0)"
    )
    conn.commit()

    count = conn.execute("SELECT COUNT(*) FROM habit_def").fetchone()[0]
    if count == 0:
        conn.executemany(
            "INSERT INTO habit_def (id, name, category, builtin, archived, sort_order) "
            "VALUES (?, ?, ?, 1, 0, ?)",
            BUILTIN_DEFAULTS,
        )
        conn.commit()

    return conn


def slugify(name):
    slug = re.sub(r"[^a-z0-9]+", "-", name.strip().lower()).strip("-")
    return slug or "habit"


def unique_id(c, base_id):
    candidate = base_id
    n = 2
    while c.execute("SELECT 1 FROM habit_def WHERE id = ?", (candidate,)).fetchone():
        candidate = f"{base_id}-{n}"
        n += 1
    return candidate


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


def fetch_defs(c):
    rows = c.execute(
        "SELECT id, name, category, builtin, archived, sort_order FROM habit_def "
        "ORDER BY archived ASC, category ASC, sort_order ASC, name ASC"
    ).fetchall()
    return [
        {
            "id": r[0],
            "name": r[1],
            "category": r[2],
            "builtin": bool(r[3]),
            "archived": bool(r[4]),
            "sortOrder": r[5],
        }
        for r in rows
    ]


def build_status(conn, target_date):
    c = conn.cursor()
    defs = fetch_defs(c)
    active_ids = [d["id"] for d in defs if not d["archived"]]

    habits = []
    for hid in active_ids:
        habits.append({
            "id": hid,
            "done": is_done(c, target_date.isoformat(), hid),
            "streak": compute_streak(c, hid, target_date),
        })

    total_xp = c.execute("SELECT COUNT(*) FROM habit_log WHERE done = 1").fetchone()[0] or 0
    level = total_xp // XP_PER_LEVEL + 1
    xp_into_level = total_xp % XP_PER_LEVEL

    heatmap = []
    habit_count = max(1, len(active_ids))
    for i in range(29, -1, -1):
        d = target_date - timedelta(days=i)
        row = c.execute(
            "SELECT COUNT(*) FROM habit_log WHERE log_date = ? AND done = 1", (d.isoformat(),)
        ).fetchone()
        done_count = row[0] or 0
        heatmap.append({"date": d.isoformat(), "ratio": done_count / habit_count})

    return {
        "defs": defs,
        "habits": habits,
        "xp": total_xp,
        "level": level,
        "xpIntoLevel": xp_into_level,
        "xpPerLevel": XP_PER_LEVEL,
        "heatmap": heatmap,
    }


def parse_date(raw):
    try:
        return date.fromisoformat(raw)
    except ValueError:
        return date.today()


def cmd_status(args):
    conn = get_conn(args.db_dir)
    print(json.dumps(build_status(conn, parse_date(args.date))))


def cmd_toggle(args):
    conn = get_conn(args.db_dir)
    target = parse_date(args.date)

    c = conn.cursor()
    currently_done = is_done(c, target.isoformat(), args.habit_id)
    new_value = 0 if currently_done else 1
    c.execute(
        "INSERT INTO habit_log (log_date, habit_id, done) VALUES (?, ?, ?) "
        "ON CONFLICT(log_date, habit_id) DO UPDATE SET done = excluded.done",
        (target.isoformat(), args.habit_id, new_value),
    )
    conn.commit()

    print(json.dumps(build_status(conn, target)))


def cmd_add_habit(args):
    conn = get_conn(args.db_dir)
    c = conn.cursor()
    name = args.name.strip()
    if not name:
        print(json.dumps(build_status(conn, date.today())))
        return

    hid = unique_id(c, slugify(name))
    max_order = c.execute("SELECT COALESCE(MAX(sort_order), -1) FROM habit_def").fetchone()[0]
    c.execute(
        "INSERT INTO habit_def (id, name, category, builtin, archived, sort_order) "
        "VALUES (?, ?, ?, 0, 0, ?)",
        (hid, name, (args.category or "").strip(), max_order + 1),
    )
    conn.commit()

    print(json.dumps(build_status(conn, date.today())))


def cmd_update_habit(args):
    conn = get_conn(args.db_dir)
    c = conn.cursor()

    row = c.execute("SELECT id FROM habit_def WHERE id = ?", (args.id,)).fetchone()
    if row:
        if args.name is not None and args.name.strip() != "":
            c.execute("UPDATE habit_def SET name = ? WHERE id = ?", (args.name.strip(), args.id))
        if args.category is not None:
            c.execute("UPDATE habit_def SET category = ? WHERE id = ?", (args.category.strip(), args.id))
        conn.commit()

    print(json.dumps(build_status(conn, date.today())))


def cmd_set_archived(args):
    conn = get_conn(args.db_dir)
    c = conn.cursor()
    c.execute("UPDATE habit_def SET archived = ? WHERE id = ?", (1 if args.archived else 0, args.id))
    conn.commit()

    print(json.dumps(build_status(conn, date.today())))


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_status = sub.add_parser("status")
    p_status.add_argument("date")
    p_status.add_argument("--db-dir", required=True)

    p_toggle = sub.add_parser("toggle")
    p_toggle.add_argument("date")
    p_toggle.add_argument("habit_id")
    p_toggle.add_argument("--db-dir", required=True)

    p_add = sub.add_parser("add-habit")
    p_add.add_argument("--db-dir", required=True)
    p_add.add_argument("--name", required=True)
    p_add.add_argument("--category", default="")

    p_update = sub.add_parser("update-habit")
    p_update.add_argument("--db-dir", required=True)
    p_update.add_argument("--id", required=True)
    p_update.add_argument("--name", default=None)
    p_update.add_argument("--category", default=None)

    p_archive = sub.add_parser("set-archived")
    p_archive.add_argument("--db-dir", required=True)
    p_archive.add_argument("--id", required=True)
    p_archive.add_argument("--archived", required=True, type=int, choices=[0, 1])

    args = parser.parse_args()
    if args.cmd == "status":
        cmd_status(args)
    elif args.cmd == "toggle":
        cmd_toggle(args)
    elif args.cmd == "add-habit":
        cmd_add_habit(args)
    elif args.cmd == "update-habit":
        cmd_update_habit(args)
    elif args.cmd == "set-archived":
        cmd_set_archived(args)


if __name__ == "__main__":
    main()
