#!/usr/bin/env python3
"""Deterministic Supabase Schema Reference Generator (Plan 21 — Wave 4).

Reads immutable SQL migrations (`supabase/migrations/*.sql`) in chronological
order without modifying them or writing to the live database, computes the
latest effective definition of every table, trigger, function, and permission
grant/revoke, and emits:
  - supabase/schema/FUNCTIONS_INDEX.md
  - supabase/schema/01_profiles_and_leaderboard.sql
  - supabase/schema/02_glory_and_knights_store.sql
  - supabase/schema/03_multiplayer_rooms_and_ghosts.sql
  - supabase/schema/04_app_control_events_and_inbox.sql
  - supabase/schema/05_dynamic_cms_library_and_quiz.sql
  - supabase/schema/06_diwan_guilds_and_live_arenas.sql
  - supabase/schema/07_admin_moderation_and_permissions.sql
  - supabase/schema/08_push_tokens_and_maintenance.sql

Usage:
  python tools/export_supabase_schema.py
"""

from __future__ import annotations

import pathlib
import re
import sys
from dataclasses import dataclass, field

ROOT = pathlib.Path(__file__).resolve().parent.parent
MIGRATIONS_DIR = ROOT / "supabase" / "migrations"
SCHEMA_DIR = ROOT / "supabase" / "schema"

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
    # 01
    "leaderboard": "01_profiles_and_leaderboard.sql",
    "user_progress": "01_profiles_and_leaderboard.sql",
    "player_directory": "01_profiles_and_leaderboard.sql",
    # 02
    "store_items": "02_glory_and_knights_store.sql",
    "user_inventory": "02_glory_and_knights_store.sql",
    # 03
    "matchmaking_queue": "03_multiplayer_rooms_and_ghosts.sql",
    "matches": "03_multiplayer_rooms_and_ghosts.sql",
    "match_participants": "03_multiplayer_rooms_and_ghosts.sql",
    "ghost_recordings": "03_multiplayer_rooms_and_ghosts.sql",
    # 04
    "app_release_config": "04_app_control_events_and_inbox.sql",
    "app_dynamic_events": "04_app_control_events_and_inbox.sql",
    "admin_announcements": "04_app_control_events_and_inbox.sql",
    "user_announcement_receipts": "04_app_control_events_and_inbox.sql",
    # 05
    "library_sections": "05_dynamic_cms_library_and_quiz.sql",
    "library_items": "05_dynamic_cms_library_and_quiz.sql",
    "quiz_categories": "05_dynamic_cms_library_and_quiz.sql",
    "quiz_questions": "05_dynamic_cms_library_and_quiz.sql",
    # 06
    "chat_messages": "06_diwan_guilds_and_live_arenas.sql",
    "guilds": "06_diwan_guilds_and_live_arenas.sql",
    "guild_members": "06_diwan_guilds_and_live_arenas.sql",
    "live_quiz_sessions": "06_diwan_guilds_and_live_arenas.sql",
    "live_quiz_participants": "06_diwan_guilds_and_live_arenas.sql",
    # 07
    "app_admins": "07_admin_moderation_and_permissions.sql",
    "player_permissions": "07_admin_moderation_and_permissions.sql",
    "diwan_moderation": "07_admin_moderation_and_permissions.sql",
    "diwan_reports": "07_admin_moderation_and_permissions.sql",
    "admin_audit_logs": "07_admin_moderation_and_permissions.sql",
    # 08
    "player_push_tokens": "08_push_tokens_and_maintenance.sql",
}

FUNCTION_DOMAIN: dict[str, str] = {
    # 01
    "sync_player_directory": "01_profiles_and_leaderboard.sql",
    "trg_fn_sync_leaderboard_glory": "01_profiles_and_leaderboard.sql",
    "trg_fn_sync_user_progress_level": "01_profiles_and_leaderboard.sql",
    # 02
    "calculate_level_and_title": "02_glory_and_knights_store.sql",
    "purchase_store_item": "02_glory_and_knights_store.sql",
    "trg_fn_guard_store_item_delete": "02_glory_and_knights_store.sql",
    # 03
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
    # 04
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
    # 05
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
    # 06
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
    # 07
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
    # 08
    "register_player_push_token": "08_push_tokens_and_maintenance.sql",
    "admin_get_push_targets": "08_push_tokens_and_maintenance.sql",
    "admin_get_resource_health": "08_push_tokens_and_maintenance.sql",
    "admin_cleanup_stale_resources": "08_push_tokens_and_maintenance.sql",
    "cleanup_stale_matches": "08_push_tokens_and_maintenance.sql",
    "cleanup_stale_queue": "08_push_tokens_and_maintenance.sql",
}


@dataclass
class TableRecord:
    name: str
    origin_migration: str
    create_sql: str
    alter_stmts: list[tuple[str, str]] = field(default_factory=list)


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
    permission_stmts: list[tuple[str, str]] = field(default_factory=list)
    granted_roles: set[str] = field(default_factory=set)
    revoked_roles: set[str] = field(default_factory=set)


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

        # Not inside string/comment/dollar-quote
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
    """Strip leading SQL comments and whitespace to reveal the statement verb."""
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
    migration_names: list[str] = []

    for mig in migrations:
        mig_name = mig.name
        migration_names.append(mig_name)
        sql = mig.read_text(encoding="utf-8")
        for raw_stmt in split_sql_statements(sql):
            head = strip_leading_comments(raw_stmt)
            if not head:
                continue

            # 1. CREATE TABLE
            m_tbl = re.match(
                r"CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(?:public\.)?([a-zA-Z0-9_]+)\b",
                head,
                re.I,
            )
            if m_tbl:
                tname = m_tbl.group(1).lower()
                tables[tname] = TableRecord(
                    name=tname,
                    origin_migration=mig_name,
                    create_sql=head,
                )
                continue

            # 2. ALTER TABLE (column/constraint evolution only; skip RLS policy toggles if duplicated)
            m_alt = re.match(
                r"ALTER\s+TABLE\s+(?:IF\s+EXISTS\s+)?(?:ONLY\s+)?(?:public\.)?([a-zA-Z0-9_]+)\s+(ADD\s+COLUMN|ALTER\s+COLUMN|ADD\s+CONSTRAINT|DROP\s+CONSTRAINT|ENABLE\s+ROW\s+LEVEL\s+SECURITY)\b",
                head,
                re.I,
            )
            if m_alt:
                tname = m_alt.group(1).lower()
                if tname in tables:
                    norm_alt = normalize_ws(head).lower()
                    existing_norms = {normalize_ws(s).lower() for _, s in tables[tname].alter_stmts}
                    if norm_alt not in existing_norms:
                        tables[tname].alter_stmts.append((mig_name, head))
                continue

            # 3. CREATE [OR REPLACE] FUNCTION
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
                after_params = head[paren_open + len(params_raw) + 2 :]
                m_ret = re.search(
                    r"RETURNS\s+(TABLE\s*\([^)]+\)|SETOF\s+[^\s]+|[^\s]+)",
                    after_params,
                    re.I,
                )
                returns = normalize_ws(m_ret.group(1)) if m_ret else "unknown"
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
                    # Reset effective grants on fresh redefinition only if re-granted later;
                    # PostgreSQL preserves grants on CREATE OR REPLACE, so keep existing sets.
                continue

            # 4. CREATE TRIGGER
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
                continue

            # 5. GRANT / REVOKE ON FUNCTION
            m_perm = re.match(
                r"(GRANT|REVOKE)\s+(?:ALL|EXECUTE)\s+ON\s+FUNCTION\s+(?:public\.)?([a-zA-Z0-9_]+)\s*\([^;]*\)\s+(?:TO|FROM)\s+([^;]+);",
                head,
                re.I | re.S,
            )
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
                continue

    return tables, triggers, functions, migration_names


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
    errors: list[str] = []
    if unmapped_tables:
        errors.append(f"Unmapped tables: {unmapped_tables}")
    if unmapped_funcs:
        errors.append(f"Unmapped functions: {unmapped_funcs}")
    if unmapped_triggers:
        errors.append(f"Unmapped triggers: {unmapped_triggers}")
    if errors:
        raise RuntimeError(
            "Schema domain mapping is incomplete! Update TABLE_DOMAIN/FUNCTION_DOMAIN:\n  "
            + "\n  ".join(errors)
        )


def write_schema_files(
    tables: dict[str, TableRecord],
    triggers: dict[str, TriggerRecord],
    functions: dict[str, FunctionRecord],
    migration_names: list[str],
) -> None:
    SCHEMA_DIR.mkdir(parents=True, exist_ok=True)
    latest_mig = migration_names[-1]

    # 1. Write the 8 domain SQL reference files
    for filename, title_ar in DOMAIN_FILES:
        dom_tables = sorted(
            (t for t in tables.values() if TABLE_DOMAIN[t.name] == filename),
            key=lambda x: x.origin_migration + ":" + x.name,
        )
        dom_triggers = sorted(
            (tr for tr in triggers.values() if TABLE_DOMAIN[tr.table_name] == filename),
            key=lambda x: x.table_name + ":" + x.name,
        )
        dom_funcs = sorted(
            (fn for fn in functions.values() if FUNCTION_DOMAIN[fn.name] == filename),
            key=lambda x: x.name,
        )

        out: list[str] = [
            f"-- ============================================================================",
            f"-- AUTO-GENERATED CANONICAL SCHEMA REFERENCE — DO NOT EDIT MANUALLY!",
            f"-- Domain: {filename} ({title_ar})",
            f"-- Source: supabase/migrations/001..{latest_mig[:3]} ({len(migration_names)} migrations)",
            f"-- Generator: python tools/export_supabase_schema.py",
            f"-- Summary: {len(dom_tables)} tables | {len(dom_triggers)} triggers | {len(dom_funcs)} functions",
            f"-- ============================================================================",
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

        if dom_triggers:
            out.append("-- ----------------------------------------------------------------------------")
            out.append("-- 2. ACTIVE TRIGGERS")
            out.append("-- ----------------------------------------------------------------------------")
            out.append("")
            for tr in dom_triggers:
                out.append(f"-- Trigger: {tr.name} ON public.{tr.table_name} (latest: {tr.migration})")
                out.append(tr.sql)
                out.append("")

        if dom_funcs:
            out.append("-- ----------------------------------------------------------------------------")
            out.append("-- 3. LATEST EFFECTIVE FUNCTIONS & RPCs")
            out.append("-- ----------------------------------------------------------------------------")
            out.append("")
            for fn in dom_funcs:
                out.append(
                    f"-- Function: public.{fn.name} | latest: {fn.latest_migration} "
                    f"| redefinitions: {fn.redefinitions} | security_definer: {fn.security_definer}"
                )
                out.append(fn.sql)
                if fn.permission_stmts:
                    out.append(f"-- Effective permission history for public.{fn.name}:")
                    for pm, pstmt in fn.permission_stmts:
                        out.append(f"--   [{pm}] {pstmt}")
                out.append("")

        (SCHEMA_DIR / filename).write_text("\n".join(out).rstrip() + "\n", encoding="utf-8")

    # 2. Write FUNCTIONS_INDEX.md
    idx_lines: list[str] = [
        "# 📚 الفهرس المرجعي الحي لجميع دوال وجداول Supabase (`FUNCTIONS_INDEX.md`)",
        "",
        f"> **توليد آلي حتمي عبر:** `python tools/export_supabase_schema.py` (لا تعدّل هذا الملف يدوياً!)",
        f"> **مصدر الحقيقة:** `supabase/migrations/001` ← `{latest_mig}` (**`{len(migration_names)}` ترحيلاً محصّناً غير قابل للتعديل**)",
        f"> **الإجمالي الموثّق:** **`{len(tables)}` جدولاً** • **`{len(triggers)}` مشغّلاً (Triggers)** • **`{len(functions)}` دالة/RPC** موزّعة على **`8` ملفات مرجعية**.",
        "",
        "---",
        "",
        "## 1️⃣ خريطة الملفات الثمانية المرجعية (`supabase/schema/`)",
        "",
        "| الملف المرجعي | المجال | الجداول | المشغّلات | الدوال |",
        "| :--- | :--- | :---: | :---: | :---: |",
    ]

    for filename, title_ar in DOMAIN_FILES:
        t_cnt = sum(1 for t in tables.values() if TABLE_DOMAIN[t.name] == filename)
        tr_cnt = sum(1 for tr in triggers.values() if TABLE_DOMAIN[tr.table_name] == filename)
        f_cnt = sum(1 for fn in functions.values() if FUNCTION_DOMAIN[fn.name] == filename)
        idx_lines.append(f"| [`{filename}`](./{filename}) | {title_ar} | {t_cnt} | {tr_cnt} | {f_cnt} |")

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
        "3. بعد تطبيق واختبار أي ترحيل جديد حياً على Supabase، يُشغّل فوراً `python tools/export_supabase_schema.py` لتحديث `supabase/schema/` و`FUNCTIONS_INDEX.md` في نفس الكوميت.",
        "",
    ])

    (SCHEMA_DIR / "FUNCTIONS_INDEX.md").write_text("\n".join(idx_lines), encoding="utf-8")


def main() -> int:
    tables, triggers, functions, migration_names = parse_migrations()
    verify_coverage(tables, triggers, functions)
    write_schema_files(tables, triggers, functions, migration_names)

    print(
        f"Exported canonical schema reference from {len(migration_names)} migrations "
        f"(latest: {migration_names[-1]}):"
    )
    print(f"  Tables:    {len(tables)}")
    print(f"  Triggers:  {len(triggers)}")
    print(f"  Functions: {len(functions)}")
    for filename, _ in DOMAIN_FILES:
        p = SCHEMA_DIR / filename
        lines = len(p.read_text(encoding="utf-8").splitlines())
        print(f"  - {filename}: {lines} lines")
    idx = SCHEMA_DIR / "FUNCTIONS_INDEX.md"
    print(f"  - FUNCTIONS_INDEX.md: {len(idx.read_text(encoding='utf-8').splitlines())} lines")
    return 0


if __name__ == "__main__":
    sys.exit(main())
