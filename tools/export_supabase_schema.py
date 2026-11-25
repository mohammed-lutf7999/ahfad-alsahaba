#!/usr/bin/env python3
"""Deterministic Supabase Schema Reference Generator (Plan 21 — Wave 4 Hardened).

Reads immutable SQL migrations (`supabase/migrations/*.sql`) in chronological
order without modifying them or writing to the live database, computes the
latest effective definition of every table, column/constraint evolution,
RLS policy, index, trigger, function, overload state, and permission grant/revoke,
and emits:
  - supabase/schema/FUNCTIONS_INDEX.md
  - supabase/schema/01_profiles_and_leaderboard.sql
  - supabase/schema/02_glory_and_knights_store.sql
  - supabase/schema/03_multiplayer_rooms_and_ghosts.sql
  - supabase/schema/04_app_control_events_and_inbox.sql
  - supabase/schema/05_dynamic_cms_library_and_quiz.sql
  - supabase/schema/06_diwan_guilds_and_live_arenas.sql
  - supabase/schema/07_admin_moderation_and_permissions.sql
  - supabase/schema/08_push_tokens_and_maintenance.sql

Optional read-only live comparison (never writes to DB, never persists tokens):
  SUPABASE_ACCESS_TOKEN=... python tools/export_supabase_schema.py --verify-live
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
import sys
import urllib.request
from dataclasses import dataclass, field

ROOT = pathlib.Path(__file__).resolve().parent.parent
MIGRATIONS_DIR = ROOT / "supabase" / "migrations"
SCHEMA_DIR = ROOT / "supabase" / "schema"
PROJECT_REF = "khatzzpqxaiwuoodgcst"

DOMAIN_FILES: list[tuple[str, str]] = [
    ("01_profiles_and_leaderboard.sql", "ملفات اللاعبين، لوحة الشرف، ودليل اللاعبين"),
    ("02_glory_and_knights_store.sql", "منظومة المجد الـ 100، متجر الفرسان، والمقتنيات"),
    ("03_multiplayer_rooms_and_ghosts.sql", "المطابقة التنافسية، المباريات، الغرف الخاصة، وأشباح الصحابة"),
    ("04_app_control_events_and_inbox.sql", "التحكم السحابي، الإصدارات، الأحداث، الإعلانات، والبريد الملكي"),
    ("05_dynamic_cms_library_and_quiz.sql", "المحتوى الديناميكي CMS، المكتبة، بنك الأسئلة، وحزم Gzip CDN"),
    ("06_diwan_guilds_and_live_arenas.sql", "ديوان الأحفاد، فلتر الأخلاق، الكتائب، والبطولات الجماعية الحية"),
    ("07_admin_moderation_and_permissions.sql", "الإشراف، حظر وصلاحيات اللاعبين، طاقم الإدارة، وسجل التدقيق"),
    ("08_push_tokens_and_maintenance.sql", "رموز الإشعارات FCM، مراقبة صحة الموارد، والتنظيف الآلي"),
]

TABLE_DOMAIN: dict[str, str] = {
    "leaderboard": "01_profiles_and_leaderboard.sql",
    "user_progress": "01_profiles_and_leaderboard.sql",
    "player_directory": "01_profiles_and_leaderboard.sql",
    "store_items": "02_glory_and_knights_store.sql",
    "user_inventory": "02_glory_and_knights_store.sql",
    "matchmaking_queue": "03_multiplayer_rooms_and_ghosts.sql",
    "matches": "03_multiplayer_rooms_and_ghosts.sql",
    "match_participants": "03_multiplayer_rooms_and_ghosts.sql",
    "ghost_recordings": "03_multiplayer_rooms_and_ghosts.sql",
    "app_release_config": "04_app_control_events_and_inbox.sql",
    "app_dynamic_events": "04_app_control_events_and_inbox.sql",
    "admin_announcements": "04_app_control_events_and_inbox.sql",
    "user_announcement_receipts": "04_app_control_events_and_inbox.sql",
    "library_sections": "05_dynamic_cms_library_and_quiz.sql",
    "library_items": "05_dynamic_cms_library_and_quiz.sql",
    "quiz_categories": "05_dynamic_cms_library_and_quiz.sql",
    "quiz_questions": "05_dynamic_cms_library_and_quiz.sql",
    "chat_messages": "06_diwan_guilds_and_live_arenas.sql",
    "guilds": "06_diwan_guilds_and_live_arenas.sql",
    "guild_members": "06_diwan_guilds_and_live_arenas.sql",
    "live_quiz_sessions": "06_diwan_guilds_and_live_arenas.sql",
    "live_quiz_participants": "06_diwan_guilds_and_live_arenas.sql",
    "app_admins": "07_admin_moderation_and_permissions.sql",
    "player_permissions": "07_admin_moderation_and_permissions.sql",
    "diwan_moderation": "07_admin_moderation_and_permissions.sql",
    "diwan_reports": "07_admin_moderation_and_permissions.sql",
    "admin_audit_logs": "07_admin_moderation_and_permissions.sql",
    "player_push_tokens": "08_push_tokens_and_maintenance.sql",
}

FUNCTION_DOMAIN: dict[str, str] = {
    "sync_player_directory": "01_profiles_and_leaderboard.sql",
    "trg_fn_sync_leaderboard_glory": "01_profiles_and_leaderboard.sql",
    "trg_fn_sync_user_progress_level": "01_profiles_and_leaderboard.sql",
    "calculate_level_and_title": "02_glory_and_knights_store.sql",
    "purchase_store_item": "02_glory_and_knights_store.sql",
    "trg_fn_guard_store_item_delete": "02_glory_and_knights_store.sql",
    "confirm_ready": "03_multiplayer_rooms_and_ghosts.sql",
    "find_or_create_match": "03_multiplayer_rooms_and_ghosts.sql",
    "submit_answer": "03_multiplayer_rooms_and_ghosts.sql",
    "finish_match": "03_multiplayer_rooms_and_ghosts.sql",
    "generate_match_question_ids": "03_multiplayer_rooms_and_ghosts.sql",
    "create_instant_rematch": "03_multiplayer_rooms_and_ghosts.sql",
    "create_private_room": "03_multiplayer_rooms_and_ghosts.sql",
    "join_private_room": "03_multiplayer_rooms_and_ghosts.sql",
    "cancel_private_room": "03_multiplayer_rooms_and_ghosts.sql",
    "find_or_create_ghost_match": "03_multiplayer_rooms_and_ghosts.sql",
    "save_ghost_timeline": "03_multiplayer_rooms_and_ghosts.sql",
    "_bump_app_config_version": "04_app_control_events_and_inbox.sql",
    "get_app_control_state": "04_app_control_events_and_inbox.sql",
    "acknowledge_announcement": "04_app_control_events_and_inbox.sql",
    "get_player_inbox": "04_app_control_events_and_inbox.sql",
    "mark_all_inbox_read": "04_app_control_events_and_inbox.sql",
    "admin_get_overview": "04_app_control_events_and_inbox.sql",
    "admin_upsert_release_config": "04_app_control_events_and_inbox.sql",
    "admin_list_announcements": "04_app_control_events_and_inbox.sql",
    "admin_create_announcement": "04_app_control_events_and_inbox.sql",
    "admin_set_announcement_active": "04_app_control_events_and_inbox.sql",
    "admin_list_dynamic_events": "04_app_control_events_and_inbox.sql",
    "admin_upsert_dynamic_event": "04_app_control_events_and_inbox.sql",
    "admin_toggle_dynamic_event": "04_app_control_events_and_inbox.sql",
    "admin_delete_dynamic_event": "04_app_control_events_and_inbox.sql",
    "_bump_cms_version": "05_dynamic_cms_library_and_quiz.sql",
    "trg_fn_cms_auto_revision": "05_dynamic_cms_library_and_quiz.sql",
    "get_cms_bundle": "05_dynamic_cms_library_and_quiz.sql",
    "get_cms_bundle_v2": "05_dynamic_cms_library_and_quiz.sql",
    "admin_list_store_items": "05_dynamic_cms_library_and_quiz.sql",
    "admin_upsert_store_item": "05_dynamic_cms_library_and_quiz.sql",
    "admin_set_content_visibility": "05_dynamic_cms_library_and_quiz.sql",
    "admin_list_library_content": "05_dynamic_cms_library_and_quiz.sql",
    "admin_upsert_library_section": "05_dynamic_cms_library_and_quiz.sql",
    "admin_upsert_library_item": "05_dynamic_cms_library_and_quiz.sql",
    "admin_list_quiz_content": "05_dynamic_cms_library_and_quiz.sql",
    "admin_upsert_quiz_category": "05_dynamic_cms_library_and_quiz.sql",
    "admin_upsert_quiz_question": "05_dynamic_cms_library_and_quiz.sql",
    "admin_update_quiz_category_config": "05_dynamic_cms_library_and_quiz.sql",
    "admin_bulk_upsert_quiz_questions": "05_dynamic_cms_library_and_quiz.sql",
    "admin_export_category_pack_payload": "05_dynamic_cms_library_and_quiz.sql",
    "admin_publish_category_pack": "05_dynamic_cms_library_and_quiz.sql",
    "trg_fn_quiz_questions_touch_updated_at": "05_dynamic_cms_library_and_quiz.sql",
    "admin_browse_quiz_questions": "05_dynamic_cms_library_and_quiz.sql",
    "admin_delete_quiz_question": "05_dynamic_cms_library_and_quiz.sql",
    "admin_bulk_manage_questions": "05_dynamic_cms_library_and_quiz.sql",
    "admin_upsert_category_availability": "05_dynamic_cms_library_and_quiz.sql",
    "admin_bulk_set_level_overrides": "05_dynamic_cms_library_and_quiz.sql",
    "admin_toggle_hidden_local_question": "05_dynamic_cms_library_and_quiz.sql",
    "_diwan_contains_profanity": "06_diwan_guilds_and_live_arenas.sql",
    "get_diwan_messages": "06_diwan_guilds_and_live_arenas.sql",
    "send_diwan_message": "06_diwan_guilds_and_live_arenas.sql",
    "report_diwan_message": "06_diwan_guilds_and_live_arenas.sql",
    "create_guild": "06_diwan_guilds_and_live_arenas.sql",
    "join_guild": "06_diwan_guilds_and_live_arenas.sql",
    "leave_guild": "06_diwan_guilds_and_live_arenas.sql",
    "contribute_guild_score": "06_diwan_guilds_and_live_arenas.sql",
    "get_guilds_overview": "06_diwan_guilds_and_live_arenas.sql",
    "create_live_quiz_session": "06_diwan_guilds_and_live_arenas.sql",
    "join_live_quiz_session": "06_diwan_guilds_and_live_arenas.sql",
    "update_live_quiz_session_state": "06_diwan_guilds_and_live_arenas.sql",
    "submit_live_quiz_answer": "06_diwan_guilds_and_live_arenas.sql",
    "check_is_admin": "07_admin_moderation_and_permissions.sql",
    "_is_user_admin": "07_admin_moderation_and_permissions.sql",
    "_check_is_owner": "07_admin_moderation_and_permissions.sql",
    "_current_actor_email": "07_admin_moderation_and_permissions.sql",
    "_write_admin_audit_log": "07_admin_moderation_and_permissions.sql",
    "_get_effective_player_permissions": "07_admin_moderation_and_permissions.sql",
    "_assert_player_allowed": "07_admin_moderation_and_permissions.sql",
    "admin_search_users": "07_admin_moderation_and_permissions.sql",
    "admin_get_player_detail": "07_admin_moderation_and_permissions.sql",
    "admin_grant_player_compensation": "07_admin_moderation_and_permissions.sql",
    "admin_upsert_player_permissions": "07_admin_moderation_and_permissions.sql",
    "admin_list_diwan_moderation_queue": "07_admin_moderation_and_permissions.sql",
    "admin_moderate_diwan": "07_admin_moderation_and_permissions.sql",
    "admin_list_guilds_and_arenas": "07_admin_moderation_and_permissions.sql",
    "admin_moderate_guild_or_arena": "07_admin_moderation_and_permissions.sql",
    "admin_list_ghosts": "07_admin_moderation_and_permissions.sql",
    "admin_toggle_ghost": "07_admin_moderation_and_permissions.sql",
    "admin_list_audit_logs": "07_admin_moderation_and_permissions.sql",
    "admin_list_admins": "07_admin_moderation_and_permissions.sql",
    "admin_manage_admin": "07_admin_moderation_and_permissions.sql",
    "register_player_push_token": "08_push_tokens_and_maintenance.sql",
    "admin_get_push_targets": "08_push_tokens_and_maintenance.sql",
    "admin_get_resource_health": "08_push_tokens_and_maintenance.sql",
    "admin_cleanup_stale_resources": "08_push_tokens_and_maintenance.sql",
    "cleanup_stale_matches": "08_push_tokens_and_maintenance.sql",
    "cleanup_stale_queue": "08_push_tokens_and_maintenance.sql",
}

ALTER_TABLE_VERB_RE = re.compile(
    r"ALTER\s+TABLE\s+(?:IF\s+EXISTS\s+)?(?:ONLY\s+)?(?:public\.)?([a-zA-Z0-9_]+)\s+"
    r"(ADD\s+COLUMN|DROP\s+COLUMN|RENAME\s+COLUMN|ALTER\s+COLUMN|ADD\s+CONSTRAINT|"
    r"DROP\s+CONSTRAINT|ENABLE\s+ROW\s+LEVEL\s+SECURITY|DISABLE\s+ROW\s+LEVEL\s+SECURITY|"
    r"FORCE\s+ROW\s+LEVEL\s+SECURITY|REPLICA\s+IDENTITY)\b",
    re.I,
)

PERM_FN_RE = re.compile(
    r"(GRANT|REVOKE)\s+(?:ALL|EXECUTE)\s+ON\s+FUNCTION\s+(?:public\.)?([a-zA-Z0-9_]+)"
    r"(?:\s*\([^;]*\))?\s+(?:TO|FROM)\s+([^;]+);",
    re.I | re.S,
)


@dataclass
class PolicyRecord:
    name: str
    table_name: str
    migration: str
    sql: str


@dataclass
class IndexRecord:
    name: str
    table_name: str
    migration: str
    sql: str


@dataclass
class TableRecord:
    name: str
    origin_migration: str
    create_sql: str
    alter_stmts: list[tuple[str, str]] = field(default_factory=list)
    policies: dict[str, PolicyRecord] = field(default_factory=dict)
    indexes: dict[str, IndexRecord] = field(default_factory=dict)


@dataclass
class TriggerRecord:
    name: str
    table_name: str
    migration: str
    sql: str


@dataclass
class FunctionRecord:
    name: str
    latest_migration: str
    sql: str
    signature: str
    returns: str
    security_definer: bool
    has_search_path: bool
    has_variable_conflict: bool
    redefinitions: int = 1
    history: list[str] = field(default_factory=list)
    active_overloads: dict[tuple[str, ...], str] = field(default_factory=dict)
    permission_stmts: list[tuple[str, str]] = field(default_factory=list)
    granted_roles: set[str] = field(default_factory=set)
    revoked_roles: set[str] = field(default_factory=set)
    alter_notes: list[tuple[str, str]] = field(default_factory=list)


def split_sql_statements(sql: str) -> list[str]:
    """Lexically split PostgreSQL script respecting comments, strings, and $tag$ blocks."""
    statements: list[str] = []
    buf: list[str] = []
    i = 0
    n = len(sql)
    in_single = False
    in_double = False
    in_line_comment = False
    in_block_comment = False
    dollar_tag: str | None = None

    while i < n:
        ch = sql[i]
        nxt = sql[i + 1] if i + 1 < n else ""

        if in_line_comment:
            buf.append(ch)
            if ch == "\n":
                in_line_comment = False
            i += 1
            continue

        if in_block_comment:
            buf.append(ch)
            if ch == "*" and nxt == "/":
                buf.append(nxt)
                in_block_comment = False
                i += 2
            else:
                i += 1
            continue

        if dollar_tag is not None:
            if sql.startswith(dollar_tag, i):
                buf.append(dollar_tag)
                i += len(dollar_tag)
                dollar_tag = None
            else:
                buf.append(ch)
                i += 1
            continue

        if in_single:
            buf.append(ch)
            if ch == "'" and nxt == "'":
                buf.append(nxt)
                i += 2
            elif ch == "'":
                in_single = False
                i += 1
            else:
                i += 1
            continue

        if in_double:
            buf.append(ch)
            if ch == '"' and nxt == '"':
                buf.append(nxt)
                i += 2
            elif ch == '"':
                in_double = False
                i += 1
            else:
                i += 1
            continue

        if ch == "-" and nxt == "-":
            buf.append("--")
            in_line_comment = True
            i += 2
            continue
        if ch == "/" and nxt == "*":
            buf.append("/*")
            in_block_comment = True
            i += 2
            continue
        if ch == "'":
            buf.append(ch)
            in_single = True
            i += 1
            continue
        if ch == '"':
            buf.append(ch)
            in_double = True
            i += 1
            continue
        if ch == "$":
            m = re.match(r"\$[A-Za-z_][A-Za-z0-9_]*\$|\$\$", sql[i:])
            if m:
                dollar_tag = m.group(0)
                buf.append(dollar_tag)
                i += len(dollar_tag)
                continue
        if ch == ";":
            buf.append(ch)
            stmt = "".join(buf).strip()
            if stmt:
                statements.append(stmt)
            buf = []
            i += 1
            continue

        buf.append(ch)
        i += 1

    tail = "".join(buf).strip()
    if tail:
        statements.append(tail)
    return statements


def strip_leading_comments(stmt: str) -> str:
    s = stmt.lstrip()
    while True:
        if s.startswith("--"):
            nl = s.find("\n")
            s = "" if nl == -1 else s[nl + 1 :].lstrip()
        elif s.startswith("/*"):
            end = s.find("*/")
            s = "" if end == -1 else s[end + 2 :].lstrip()
        else:
            break
    return s


def extract_balanced_parens(text: str, open_idx: int) -> str:
    depth = 0
    in_single = False
    for idx in range(open_idx, len(text)):
        ch = text[idx]
        if in_single:
            if ch == "'":
                in_single = False
            continue
        if ch == "'":
            in_single = True
        elif ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                return text[open_idx + 1 : idx]
    return ""


def normalize_ws(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


def parse_roles(roles_str: str) -> list[str]:
    return [r.strip().lower() for r in roles_str.split(",") if r.strip()]


def extract_arg_types(params_str: str) -> tuple[str, ...]:
    """Normalize PostgreSQL function parameter list into canonical type tuple."""
    if not params_str.strip():
        return ()
    args: list[str] = []
    depth = 0
    in_sq = False
    cur: list[str] = []
    for ch in params_str:
        if in_sq:
            cur.append(ch)
            if ch == "'":
                in_sq = False
            continue
        if ch == "'":
            in_sq = True
            cur.append(ch)
        elif ch == "(":
            depth += 1
            cur.append(ch)
        elif ch == ")":
            depth -= 1
            cur.append(ch)
        elif ch == "," and depth == 0:
            args.append("".join(cur).strip())
            cur = []
        else:
            cur.append(ch)
    if cur:
        args.append("".join(cur).strip())

    types: list[str] = []
    for raw in args:
        if not raw:
            continue
        a = re.split(r"\bDEFAULT\b|=", raw, maxsplit=1, flags=re.I)[0].strip()
        a = re.sub(r"^(?:IN|OUT|INOUT|VARIADIC)\s+", "", a, flags=re.I).strip()
        toks = a.split()
        if len(toks) >= 2 and toks[0].upper() not in {
            "DOUBLE",
            "CHARACTER",
            "TIMESTAMP",
            "TIME",
            "BIT",
        }:
            t = " ".join(toks[1:])
        else:
            t = " ".join(toks)
        t = normalize_ws(t).lower()
        t = (
            t.replace("integer", "int")
            .replace("int4", "int")
            .replace("bigint", "int8")
            .replace("boolean", "bool")
            .replace("character varying", "varchar")
            .replace("timestamptz", "timestamp with time zone")
        )
        t = re.sub(r"\(\d+(?:,\s*\d+)?\)", "", t)
        types.append(t)
    return tuple(types)


def extract_returns_clause(after_params: str) -> str:
    """Extract RETURNS clause safely, handling nested parens inside RETURNS TABLE(...)."""
    m_tbl = re.search(r"\bRETURNS\s+TABLE\s*\(", after_params, re.I)
    if m_tbl:
        open_idx = after_params.find("(", m_tbl.start())
        inner = extract_balanced_parens(after_params, open_idx)
        return f"TABLE({normalize_ws(inner)})"
    m_ret = re.search(r"\bRETURNS\s+(SETOF\s+[^\s]+|[^\s]+)", after_params, re.I)
    return normalize_ws(m_ret.group(1)) if m_ret else "unknown"


def _apply_ddl_statement(
    head: str,
    mig_name: str,
    tables: dict[str, TableRecord],
    triggers: dict[str, TriggerRecord],
    functions: dict[str, FunctionRecord],
    index_to_table: dict[str, str],
) -> None:
    """Process one normalized DDL/DCL statement into canonical state."""
    # 1. CREATE TABLE (guarded so repeated CREATE TABLE IF NOT EXISTS never wipes ALTERs/policies/indexes)
    m_tbl = re.match(
        r"CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(?:public\.)?([a-zA-Z0-9_]+)\b",
        head,
        re.I,
    )
    if m_tbl:
        tname = m_tbl.group(1).lower()
        if tname not in tables:
            tables[tname] = TableRecord(
                name=tname,
                origin_migration=mig_name,
                create_sql=head,
            )
        return

    # 2. ALTER TABLE (column/constraint/RLS/replica identity evolution)
    m_alt = ALTER_TABLE_VERB_RE.match(head)
    if m_alt:
        tname = m_alt.group(1).lower()
        if tname in tables:
            norm_alt = normalize_ws(head).lower()
            existing_norms = {normalize_ws(s).lower() for _, s in tables[tname].alter_stmts}
            if norm_alt not in existing_norms:
                tables[tname].alter_stmts.append((mig_name, head))
        return

    # 3. DROP POLICY
    m_dp = re.match(
        r'DROP\s+POLICY\s+(?:IF\s+EXISTS\s+)?"([^"]+)"\s+ON\s+(?:public\.)?([a-zA-Z0-9_]+)\b',
        head,
        re.I,
    )
    if m_dp:
        pname = m_dp.group(1)
        tname = m_dp.group(2).lower()
        if tname in tables:
            tables[tname].policies.pop(pname.lower(), None)
        return

    # 4. CREATE POLICY
    m_cp = re.match(
        r'CREATE\s+POLICY\s+"([^"]+)"\s+ON\s+(?:public\.)?([a-zA-Z0-9_]+)\b',
        head,
        re.I,
    )
    if m_cp:
        pname = m_cp.group(1)
        tname = m_cp.group(2).lower()
        if tname in tables:
            tables[tname].policies[pname.lower()] = PolicyRecord(
                name=pname,
                table_name=tname,
                migration=mig_name,
                sql=head,
            )
        return

    # 5. DROP INDEX
    m_di = re.match(
        r"DROP\s+INDEX\s+(?:CONCURRENTLY\s+)?(?:IF\s+EXISTS\s+)?(?:public\.)?([a-zA-Z0-9_]+)\b",
        head,
        re.I,
    )
    if m_di:
        iname = m_di.group(1).lower()
        tname = index_to_table.pop(iname, None)
        if tname and tname in tables:
            tables[tname].indexes.pop(iname, None)
        return

    # 6. CREATE [UNIQUE] INDEX
    m_ci = re.match(
        r"CREATE\s+(?:UNIQUE\s+)?INDEX\s+(?:CONCURRENTLY\s+)?(?:IF\s+NOT\s+EXISTS\s+)?([a-zA-Z0-9_]+)\s+ON\s+(?:ONLY\s+)?(?:public\.)?([a-zA-Z0-9_]+)\b",
        head,
        re.I,
    )
    if m_ci:
        iname = m_ci.group(1).lower()
        tname = m_ci.group(2).lower()
        if tname in tables:
            tables[tname].indexes[iname] = IndexRecord(
                name=iname,
                table_name=tname,
                migration=mig_name,
                sql=head,
            )
            index_to_table[iname] = tname
        return

    # 7. DROP FUNCTION (tracks overload cleanup & resets grants when fully dropped)
    m_df = re.match(
        r"DROP\s+FUNCTION\s+(?:IF\s+EXISTS\s+)?(?:public\.)?([a-zA-Z0-9_]+)(?:\s*\()?",
        head,
        re.I,
    )
    if m_df:
        fname = m_df.group(1).lower()
        fn = functions.get(fname)
        if fn is not None:
            paren_open = head.find("(", m_df.start())
            if paren_open != -1:
                pr = extract_balanced_parens(head, paren_open)
                fn.active_overloads.pop(extract_arg_types(pr), None)
            else:
                fn.active_overloads.clear()
            if not fn.active_overloads:
                # Dropped completely: PostgreSQL drops prior ACLs when function is dropped
                fn.granted_roles.clear()
                fn.revoked_roles.clear()
                fn.permission_stmts.clear()
        return

    # 8. CREATE [OR REPLACE] FUNCTION
    m_fn = re.match(
        r"CREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION\s+(?:public\.)?([a-zA-Z0-9_]+)\s*\(",
        head,
        re.I,
    )
    if m_fn:
        fname = m_fn.group(1).lower()
        paren_open = head.find("(", m_fn.start())
        params_raw = extract_balanced_parens(head, paren_open)
        params_clean = normalize_ws(params_raw)
        arg_types = extract_arg_types(params_raw)
        after_params = head[paren_open + len(params_raw) + 2 :]
        returns = extract_returns_clause(after_params)
        sec_def = bool(re.search(r"\bSECURITY\s+DEFINER\b", head, re.I))
        has_sp = bool(re.search(r"\bSET\s+search_path\b", head, re.I))
        has_vc = "#variable_conflict" in head.lower()

        prev = functions.get(fname)
        if prev is None:
            functions[fname] = FunctionRecord(
                name=fname,
                latest_migration=mig_name,
                sql=head,
                signature=f"{fname}({params_clean})",
                returns=returns,
                security_definer=sec_def,
                has_search_path=has_sp,
                has_variable_conflict=has_vc,
                redefinitions=1,
                history=[mig_name],
                active_overloads={arg_types: mig_name},
            )
        else:
            prev.latest_migration = mig_name
            prev.sql = head
            prev.signature = f"{fname}({params_clean})"
            prev.returns = returns
            prev.security_definer = sec_def
            prev.has_search_path = has_sp
            prev.has_variable_conflict = has_vc
            prev.redefinitions += 1
            prev.history.append(mig_name)
            prev.active_overloads[arg_types] = mig_name
        return

    # 9. ALTER FUNCTION ... SET search_path
    m_af = re.match(
        r"ALTER\s+FUNCTION\s+(?:public\.)?([a-zA-Z0-9_]+)\s*(?:\([^;]*\))?\s+SET\s+search_path\b",
        head,
        re.I,
    )
    if m_af:
        fn = functions.get(m_af.group(1).lower())
        if fn is not None:
            fn.has_search_path = True
            fn.alter_notes.append((mig_name, normalize_ws(head)))
        return

    # 10. DROP TRIGGER
    m_dt = re.match(
        r"DROP\s+TRIGGER\s+(?:IF\s+EXISTS\s+)?([a-zA-Z0-9_]+)\s+ON\s+(?:public\.)?([a-zA-Z0-9_]+)\b",
        head,
        re.I,
    )
    if m_dt:
        triggers.pop(m_dt.group(1).lower(), None)
        return

    # 11. CREATE TRIGGER
    m_tr = re.match(
        r"CREATE\s+(?:OR\s+REPLACE\s+)?TRIGGER\s+([a-zA-Z0-9_]+)\s+(?:BEFORE|AFTER|INSTEAD\s+OF)\s+[\s\S]+?\s+ON\s+(?:public\.)?([a-zA-Z0-9_]+)\b",
        head,
        re.I,
    )
    if m_tr:
        tr_name = m_tr.group(1).lower()
        tbl_name = m_tr.group(2).lower()
        triggers[tr_name] = TriggerRecord(
            name=tr_name,
            table_name=tbl_name,
            migration=mig_name,
            sql=head,
        )
        return

    # 12. GRANT / REVOKE ON FUNCTION (parentheses optional)
    m_perm = PERM_FN_RE.match(head)
    if m_perm:
        verb = m_perm.group(1).upper()
        fname = m_perm.group(2).lower()
        roles = parse_roles(m_perm.group(3))
        fn = functions.get(fname)
        if fn is not None:
            fn.permission_stmts.append((mig_name, normalize_ws(head)))
            if verb == "GRANT":
                for r in roles:
                    fn.granted_roles.add(r)
                    fn.revoked_roles.discard(r)
            else:
                for r in roles:
                    fn.revoked_roles.add(r)
                    fn.granted_roles.discard(r)
        return


def _apply_do_block_effects(
    head: str,
    mig_name: str,
    tables: dict[str, TableRecord],
    triggers: dict[str, TriggerRecord],
    functions: dict[str, FunctionRecord],
    index_to_table: dict[str, str],
) -> None:
    """Extract idempotent DDL/hardening statements executed inside DO $$ ... $$ blocks."""
    # Extract inner body between first $tag$ and matching closing $tag$
    m_tag = re.search(r"\$[A-Za-z_][A-Za-z0-9_]*\$|\$\$", head)
    if not m_tag:
        return
    tag = m_tag.group(0)
    start = m_tag.end()
    end = head.rfind(tag)
    if end <= start:
        return
    body = head[start:end]

    # A) Dynamic ALTER FUNCTION ... SET search_path loops over p.proname IN (...)
    if "SET search_path" in body and "p.proname IN" in body:
        m_in = re.search(r"p\.proname\s+IN\s*\(([^)]+)\)", body, re.I | re.S)
        if m_in:
            for nm in re.findall(r"'([a-zA-Z0-9_]+)'", m_in.group(1)):
                fn = functions.get(nm.lower())
                if fn is not None:
                    fn.has_search_path = True
                    fn.alter_notes.append(
                        (
                            mig_name,
                            f"ALTER FUNCTION public.{nm.lower()} SET search_path = public, auth; -- via DO block",
                        )
                    )

    # A2) Dynamic REVOKE ALL ... FROM PUBLIC, anon on admin_* and _* (024a hardening)
    if "REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon" in body and "admin\\_" in body:
        for fname, fn in functions.items():
            if fname.startswith("admin_") or fname.startswith("_"):
                fn.revoked_roles.update({"public", "anon"})
                fn.granted_roles.discard("public")
                fn.granted_roles.discard("anon")
                if fname.startswith("admin_") or fname in {"_check_is_owner", "_current_actor_email"}:
                    fn.granted_roles.update({"authenticated", "service_role"})
                    fn.revoked_roles.discard("authenticated")
                    fn.revoked_roles.discard("service_role")
                else:
                    fn.revoked_roles.add("authenticated")
                    fn.granted_roles.discard("authenticated")
                    fn.granted_roles.add("service_role")
                    fn.revoked_roles.discard("service_role")
                fn.permission_stmts.append(
                    (mig_name, f"REVOKE ALL ON FUNCTION public.{fname} FROM PUBLIC, anon; -- via DO block")
                )

    # B) Direct DROP POLICY / CREATE POLICY / ALTER TABLE / GRANT / REVOKE inside DO $$
    for inner_stmt in split_sql_statements(body):
        # Strip leading PL/pgSQL control tokens (BEGIN / IF ... THEN / ELSE)
        cleaned = strip_leading_comments(inner_stmt)
        cleaned = re.sub(
            r"^(?:BEGIN\s+|IF\s+[\s\S]+?\s+THEN\s+|ELSE\s+|END\s+IF\s*;\s*)+",
            "",
            cleaned,
            flags=re.I,
        ).strip()
        if cleaned:
            _apply_ddl_statement(
                cleaned, mig_name, tables, triggers, functions, index_to_table
            )


def parse_migrations() -> tuple[
    dict[str, TableRecord],
    dict[str, TriggerRecord],
    dict[str, FunctionRecord],
    list[str],
]:
    migrations = sorted(MIGRATIONS_DIR.glob("*.sql"))
    if not migrations:
        raise RuntimeError(f"No migration files found in {MIGRATIONS_DIR}")

    tables: dict[str, TableRecord] = {}
    triggers: dict[str, TriggerRecord] = {}
    functions: dict[str, FunctionRecord] = {}
    index_to_table: dict[str, str] = {}
    migration_names: list[str] = []

    for mig in migrations:
        mig_name = mig.name
        migration_names.append(mig_name)
        sql = mig.read_text(encoding="utf-8")
        for raw_stmt in split_sql_statements(sql):
            head = strip_leading_comments(raw_stmt)
            if not head:
                continue
            if re.match(r"DO\s+\$", head, re.I):
                _apply_do_block_effects(
                    head, mig_name, tables, triggers, functions, index_to_table
                )
            else:
                _apply_ddl_statement(
                    head, mig_name, tables, triggers, functions, index_to_table
                )

    # Prune any function that was dropped and never recreated
    active_functions = {k: v for k, v in functions.items() if v.active_overloads}
    return tables, triggers, active_functions, migration_names


def format_permissions(fn: FunctionRecord) -> str:
    if not fn.granted_roles and not fn.revoked_roles:
        return "PostgreSQL default (`PUBLIC` / RLS-scoped)"
    parts: list[str] = []
    if fn.granted_roles:
        parts.append("GRANT: `" + ", ".join(sorted(fn.granted_roles)) + "`")
    if fn.revoked_roles:
        parts.append("REVOKE: `" + ", ".join(sorted(fn.revoked_roles)) + "`")
    return " • ".join(parts)


def verify_coverage(
    tables: dict[str, TableRecord],
    triggers: dict[str, TriggerRecord],
    functions: dict[str, FunctionRecord],
) -> None:
    unmapped_tables = sorted(set(tables) - set(TABLE_DOMAIN))
    unmapped_funcs = sorted(set(functions) - set(FUNCTION_DOMAIN))
    unmapped_triggers = sorted(
        tr.name for tr in triggers.values() if tr.table_name not in TABLE_DOMAIN
    )
    overloads = {
        fn.name: fn.active_overloads
        for fn in functions.values()
        if len(fn.active_overloads) > 1
    }
    errors: list[str] = []
    if unmapped_tables:
        errors.append(f"Unmapped tables: {unmapped_tables}")
    if unmapped_funcs:
        errors.append(f"Unmapped functions: {unmapped_funcs}")
    if unmapped_triggers:
        errors.append(f"Unmapped triggers: {unmapped_triggers}")
    if overloads:
        errors.append(f"Undropped function overloads (PGRST203 risk): {overloads}")
    if errors:
        raise RuntimeError("Schema verification failed:\n  " + "\n  ".join(errors))


def write_schema_files(
    tables: dict[str, TableRecord],
    triggers: dict[str, TriggerRecord],
    functions: dict[str, FunctionRecord],
    migration_names: list[str],
) -> None:
    SCHEMA_DIR.mkdir(parents=True, exist_ok=True)
    latest_mig = migration_names[-1]
    total_policies = sum(len(t.policies) for t in tables.values())
    total_indexes = sum(len(t.indexes) for t in tables.values())

    for filename, title_ar in DOMAIN_FILES:
        dom_tables = sorted(
            (t for t in tables.values() if TABLE_DOMAIN[t.name] == filename),
            key=lambda x: x.origin_migration + ":" + x.name,
        )
        dom_policies = [
            pol
            for t in dom_tables
            for pol in sorted(t.policies.values(), key=lambda x: x.name.lower())
        ]
        dom_indexes = [
            idx
            for t in dom_tables
            for idx in sorted(t.indexes.values(), key=lambda x: x.name)
        ]
        dom_triggers = sorted(
            (tr for tr in triggers.values() if TABLE_DOMAIN[tr.table_name] == filename),
            key=lambda x: x.table_name + ":" + x.name,
        )
        dom_funcs = sorted(
            (fn for fn in functions.values() if FUNCTION_DOMAIN[fn.name] == filename),
            key=lambda x: x.name,
        )

        out: list[str] = [
            "-- ============================================================================",
            "-- AUTO-GENERATED CANONICAL SCHEMA REFERENCE — DO NOT EDIT MANUALLY!",
            f"-- Domain: {filename} ({title_ar})",
            f"-- Source: supabase/migrations/001..{latest_mig[:3]} ({len(migration_names)} migrations)",
            "-- Generator: python tools/export_supabase_schema.py",
            f"-- Summary: {len(dom_tables)} tables | {len(dom_policies)} RLS policies | {len(dom_indexes)} indexes | {len(dom_triggers)} triggers | {len(dom_funcs)} functions",
            "-- ============================================================================",
            "",
        ]

        if dom_tables:
            out.append("-- ----------------------------------------------------------------------------")
            out.append("-- 1. TABLES & COLUMN/CONSTRAINT EVOLUTION")
            out.append("-- ----------------------------------------------------------------------------")
            out.append("")
            for tbl in dom_tables:
                out.append(f"-- Table: public.{tbl.name} (origin: {tbl.origin_migration})")
                out.append(tbl.create_sql)
                if tbl.alter_stmts:
                    out.append(f"-- Effective ALTERs for public.{tbl.name}:")
                    for am, astmt in tbl.alter_stmts:
                        out.append(f"--   [{am}]")
                        out.append(astmt)
                out.append("")

        if dom_policies:
            out.append("-- ----------------------------------------------------------------------------")
            out.append("-- 2. ACTIVE RLS POLICIES")
            out.append("-- ----------------------------------------------------------------------------")
            out.append("")
            for pol in dom_policies:
                out.append(f'-- Policy: "{pol.name}" ON public.{pol.table_name} (latest: {pol.migration})')
                out.append(pol.sql)
                out.append("")

        if dom_indexes:
            out.append("-- ----------------------------------------------------------------------------")
            out.append("-- 3. ACTIVE INDEXES")
            out.append("-- ----------------------------------------------------------------------------")
            out.append("")
            for idx in dom_indexes:
                out.append(f"-- Index: {idx.name} ON public.{idx.table_name} (origin: {idx.migration})")
                out.append(idx.sql)
                out.append("")

        if dom_triggers:
            out.append("-- ----------------------------------------------------------------------------")
            out.append("-- 4. ACTIVE TRIGGERS")
            out.append("-- ----------------------------------------------------------------------------")
            out.append("")
            for tr in dom_triggers:
                out.append(f"-- Trigger: {tr.name} ON public.{tr.table_name} (latest: {tr.migration})")
                out.append(tr.sql)
                out.append("")

        if dom_funcs:
            out.append("-- ----------------------------------------------------------------------------")
            out.append("-- 5. LATEST EFFECTIVE FUNCTIONS & RPCs")
            out.append("-- ----------------------------------------------------------------------------")
            out.append("")
            for fn in dom_funcs:
                out.append(
                    f"-- Function: public.{fn.name} | latest: {fn.latest_migration} "
                    f"| redefinitions: {fn.redefinitions} | security_definer: {fn.security_definer} "
                    f"| search_path: {fn.has_search_path}"
                )
                out.append(fn.sql)
                if fn.alter_notes:
                    out.append(f"-- Effective ALTER FUNCTION notes for public.{fn.name}:")
                    for am, anote in fn.alter_notes:
                        out.append(f"--   [{am}] {anote}")
                if fn.permission_stmts:
                    out.append(f"-- Effective permission history for public.{fn.name}:")
                    for pm, pstmt in fn.permission_stmts:
                        out.append(f"--   [{pm}] {pstmt}")
                out.append("")

        (SCHEMA_DIR / filename).write_text("\n".join(out).rstrip() + "\n", encoding="utf-8")

    idx_lines: list[str] = [
        "# 📚 الفهرس المرجعي الحي لجميع دوال وجداول وسياسات Supabase (`FUNCTIONS_INDEX.md`)",
        "",
        "> **توليد آلي حتمي عبر:** `python tools/export_supabase_schema.py` (لا تعدّل هذا الملف يدوياً!)",
        f"> **مصدر الحقيقة:** `supabase/migrations/001` ← `{latest_mig}` (**`{len(migration_names)}` ترحيلاً محصّناً غير قابل للتعديل**)",
        f"> **الإجمالي الموثّق:** **`{len(tables)}` جدولاً** • **`{total_policies}` سياسة RLS** • **`{total_indexes}` فهرساً** • **`{len(triggers)}` مشغّلاً** • **`{len(functions)}` دالة/RPC** • **`0` توقيعات مكررة (`PGRST203`)**.",
        "",
        "---",
        "",
        "## 1️⃣ خريطة الملفات الثمانية المرجعية (`supabase/schema/`)",
        "",
        "| الملف المرجعي | المجال | الجداول | سياسات RLS | الفهارس | المشغّلات | الدوال |",
        "| :--- | :--- | :---: | :---: | :---: | :---: | :---: |",
    ]

    for filename, title_ar in DOMAIN_FILES:
        dom_t = [t for t in tables.values() if TABLE_DOMAIN[t.name] == filename]
        t_cnt = len(dom_t)
        p_cnt = sum(len(t.policies) for t in dom_t)
        i_cnt = sum(len(t.indexes) for t in dom_t)
        tr_cnt = sum(1 for tr in triggers.values() if TABLE_DOMAIN[tr.table_name] == filename)
        f_cnt = sum(1 for fn in functions.values() if FUNCTION_DOMAIN[fn.name] == filename)
        idx_lines.append(
            f"| [`{filename}`](./{filename}) | {title_ar} | {t_cnt} | {p_cnt} | {i_cnt} | {tr_cnt} | {f_cnt} |"
        )

    idx_lines.extend([
        "",
        "---",
        "",
        "## 2️⃣ فهرس الدوال الكامل (آخر تعريف حيّ معتمد لكل دالة)",
        "",
        "| # | الدالة (`public.*`) | الملف المرجعي | آخر ترحيل | مرات التعريف | الأمان | الصلاحيات الفعلية | القيمة المُعادة |",
        "| :-: | :--- | :--- | :--- | :---: | :---: | :--- | :--- |",
    ])

    for i, fn in enumerate(sorted(functions.values(), key=lambda x: x.name), 1):
        dom = FUNCTION_DOMAIN[fn.name]
        sec_flags: list[str] = []
        if fn.security_definer:
            sec_flags.append("`DEFINER`")
        if fn.has_search_path:
            sec_flags.append("`search_path`")
        if fn.has_variable_conflict:
            sec_flags.append("`#vc`")
        sec_str = " ".join(sec_flags) if sec_flags else "`INVOKER`"
        perms = format_permissions(fn)
        ret_short = fn.returns if len(fn.returns) <= 36 else fn.returns[:33] + "..."
        idx_lines.append(
            f"| {i} | `{fn.name}` | [`{dom}`](./{dom}) | `{fn.latest_migration}` | {fn.redefinitions} | {sec_str} | {perms} | `{ret_short}` |"
        )

    idx_lines.extend([
        "",
        "---",
        "",
        "## 3️⃣ ميثاق الترحيلات المستقبلية (`024+` فما فوق)",
        "1. تبقى جميع الملفات `supabase/migrations/001..023` **محصّنة بلا تعديل أو حذف**.",
        "2. يُحدّ أي ترحيل جديد بحد أقصى `~400` سطر للملف الواحد مع `#variable_conflict use_column` و`SET search_path = public, auth` وسحب `PUBLIC, anon` عن أي دالة إدارية أو داخلية.",
        "3. بعد تطبيق واختبار أي ترحيل جديد حياً على Supabase، يُشغّل فوراً `python tools/export_supabase_schema.py` لتحديث `supabase/schema/` و`FUNCTIONS_INDEX.md` في نفس الكوميت (ويمكن التحقق الحي للقراءة فقط عبر `SUPABASE_ACCESS_TOKEN=... python tools/export_supabase_schema.py --verify-live`).",
        "",
    ])

    (SCHEMA_DIR / "FUNCTIONS_INDEX.md").write_text("\n".join(idx_lines), encoding="utf-8")


def verify_against_live_readonly(
    tables: dict[str, TableRecord],
    triggers: dict[str, TriggerRecord],
    functions: dict[str, FunctionRecord],
) -> int:
    """Read-only SELECT comparison against live Supabase catalog via Management API."""
    token = os.environ.get("SUPABASE_ACCESS_TOKEN", "").strip()
    if not token:
        print(
            "ERROR: SUPABASE_ACCESS_TOKEN environment variable is not set. "
            "Cannot run --verify-live read-only catalog comparison.",
            file=sys.stderr,
        )
        return 2

    query = """
    SELECT json_build_object(
      'tables', (SELECT COALESCE(json_agg(tablename ORDER BY tablename), '[]'::json)
                 FROM pg_tables WHERE schemaname = 'public'),
      'policies', (SELECT COALESCE(json_agg(json_build_object('table', tablename, 'policy', policyname) ORDER BY tablename, policyname), '[]'::json)
                   FROM pg_policies WHERE schemaname = 'public'),
      'triggers', (SELECT COALESCE(json_agg(json_build_object('table', c.relname, 'trigger', t.tgname) ORDER BY c.relname, t.tgname), '[]'::json)
                   FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid JOIN pg_namespace n ON n.oid = c.relnamespace
                   WHERE n.nspname = 'public' AND NOT t.tgisinternal),
      'functions', (SELECT COALESCE(json_agg(json_build_object(
                      'name', p.proname,
                      'sig', p.oid::regprocedure::text,
                      'anon_exec', has_function_privilege('anon', p.oid, 'EXECUTE')
                    ) ORDER BY p.proname, p.oid), '[]'::json)
                    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                    WHERE n.nspname = 'public' AND p.prokind = 'f')
    ) AS snapshot;
    """
    req = urllib.request.Request(
        f"https://api.supabase.com/v1/projects/{PROJECT_REF}/database/query",
        data=json.dumps({"query": query}).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "User-Agent": "ahfad-schema-verifier/1.0",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=20) as resp:
        rows = json.loads(resp.read().decode("utf-8"))
    snap = rows[0]["snapshot"]

    live_tables = set(snap["tables"])
    local_tables = set(tables)
    live_funcs_list = snap["functions"]
    live_func_names = {f["name"] for f in live_funcs_list}
    local_func_names = set(functions)

    # Check live overloads
    counts: dict[str, list[str]] = {}
    for f in live_funcs_list:
        counts.setdefault(f["name"], []).append(f["sig"])
    live_overloads = {k: v for k, v in counts.items() if len(v) > 1}
    live_admin_anon = [
        f["sig"]
        for f in live_funcs_list
        if f["anon_exec"] and (f["name"].startswith("admin_") or f["name"].startswith("_"))
    ]

    print(f"Live tables ({len(live_tables)}) vs Local ({len(local_tables)}): diff_live={sorted(live_tables - local_tables)}, diff_local={sorted(local_tables - live_tables)}")
    print(f"Live functions ({len(live_func_names)}) vs Local ({len(local_func_names)}): diff_live={sorted(live_func_names - local_func_names)}, diff_local={sorted(local_func_names - live_func_names)}")
    print(f"Live triggers ({len(snap['triggers'])}) vs Local ({len(triggers)})")
    print(f"Live RLS policies ({len(snap['policies'])}) vs Local ({sum(len(t.policies) for t in tables.values())})")
    print(f"Live function overloads: {live_overloads}")
    print(f"Live admin_*/_* executable by anon: {live_admin_anon}")

    if live_tables != local_tables or live_func_names != local_func_names or live_overloads or live_admin_anon:
        return 1
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Export canonical Supabase schema reference.")
    parser.add_argument(
        "--verify-live",
        action="store_true",
        help="Run read-only catalog comparison against live Supabase using SUPABASE_ACCESS_TOKEN env var.",
    )
    args = parser.parse_args()

    tables, triggers, functions, migration_names = parse_migrations()
    verify_coverage(tables, triggers, functions)
    write_schema_files(tables, triggers, functions, migration_names)

    total_policies = sum(len(t.policies) for t in tables.values())
    total_indexes = sum(len(t.indexes) for t in tables.values())
    print(
        f"Exported canonical schema reference from {len(migration_names)} migrations "
        f"(latest: {migration_names[-1]}):"
    )
    print(
        f"  Tables: {len(tables)} | RLS Policies: {total_policies} | "
        f"Indexes: {total_indexes} | Triggers: {len(triggers)} | Functions: {len(functions)} | Overloads: 0"
    )
    for filename, _ in DOMAIN_FILES:
        p = SCHEMA_DIR / filename
        lines = len(p.read_text(encoding="utf-8").splitlines())
        print(f"  - {filename}: {lines} lines")
    idx = SCHEMA_DIR / "FUNCTIONS_INDEX.md"
    print(f"  - FUNCTIONS_INDEX.md: {len(idx.read_text(encoding='utf-8').splitlines())} lines")

    if args.verify_live:
        return verify_against_live_readonly(tables, triggers, functions)
    return 0


if __name__ == "__main__":
    sys.exit(main())
