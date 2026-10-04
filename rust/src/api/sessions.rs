use crate::get_db;
use crate::models::session::{Session, SessionSummary};
use sqlx::SqlitePool;

pub async fn create_session(title: String) -> anyhow::Result<Session> {
    let pool = get_db()?;
    let session = Session::new(title);
    sqlx::query(
        "INSERT INTO sessions (session_id, title, status, share_code, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?)",
    )
    .bind(&session.session_id)
    .bind(&session.title)
    .bind(&session.status)
    .bind(&session.share_code)
    .bind(&session.created_at)
    .bind(&session.updated_at)
    .execute(pool)
    .await?;
    Ok(session)
}

/// Starts a new writable local session atomically.
///
/// Opening another recorder does not end existing sessions. Only an explicit
/// end action changes their lifecycle.
pub async fn start_local_session(title: String) -> anyhow::Result<Session> {
    start_local_session_from_pool(get_db()?, &title).await
}

async fn start_local_session_from_pool(pool: &SqlitePool, title: &str) -> anyhow::Result<Session> {
    let title = title.trim();
    if title.is_empty() || title.chars().count() > 200 {
        anyhow::bail!("SESSION_TITLE_INVALID");
    }

    let mut tx = pool.begin().await?;
    let session = Session::new(title.to_string());
    sqlx::query(
        "INSERT INTO sessions (session_id, title, status, share_code, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?)",
    )
    .bind(&session.session_id)
    .bind(&session.title)
    .bind(&session.status)
    .bind(&session.share_code)
    .bind(&session.created_at)
    .bind(&session.updated_at)
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;
    Ok(session)
}

pub async fn list_sessions() -> anyhow::Result<Vec<Session>> {
    let pool = get_db()?;
    let rows = sqlx::query_as::<_, SessionRow>(
        "SELECT * FROM sessions WHERE deleted_at IS NULL ORDER BY created_at DESC",
    )
    .fetch_all(pool)
    .await?;
    Ok(rows.into_iter().map(|r| r.into_session()).collect())
}

pub async fn list_session_summaries() -> anyhow::Result<Vec<SessionSummary>> {
    list_session_summaries_from_pool(get_db()?).await
}

/// Closes active local-only Sessions after two hours without a persisted
/// record or Session change.
///
/// Collaboration replicas are deliberately excluded because their canonical
/// lifecycle belongs to the server. The cutoff is rechecked in the same
/// transaction as each close so a concurrent record write wins over the
/// maintenance sweep.
pub async fn close_inactive_local_sessions() -> anyhow::Result<Vec<Session>> {
    let closed_at = chrono::Utc::now();
    let cutoff = closed_at - chrono::Duration::hours(2);
    close_inactive_local_sessions_from_pool(
        get_db()?,
        &cutoff.to_rfc3339(),
        &closed_at.to_rfc3339(),
    )
    .await
}

async fn close_inactive_local_sessions_from_pool(
    pool: &SqlitePool,
    cutoff: &str,
    closed_at: &str,
) -> anyhow::Result<Vec<Session>> {
    chrono::DateTime::parse_from_rfc3339(cutoff)
        .map_err(|_| anyhow::anyhow!("SESSION_INACTIVITY_CUTOFF_INVALID"))?;
    chrono::DateTime::parse_from_rfc3339(closed_at)
        .map_err(|_| anyhow::anyhow!("SESSION_INACTIVITY_CLOSE_TIME_INVALID"))?;

    let mut tx = pool.begin().await?;
    let candidate_ids: Vec<(String,)> = sqlx::query_as(
        "SELECT sessions.session_id
         FROM sessions
         WHERE sessions.status = 'active'
           AND sessions.deleted_at IS NULL
           AND julianday(sessions.updated_at) < julianday(?)
           AND NOT EXISTS (
               SELECT 1 FROM collaboration_bindings binding
               WHERE binding.session_id = sessions.session_id
           )
         ORDER BY sessions.updated_at ASC, sessions.session_id ASC",
    )
    .bind(cutoff)
    .fetch_all(&mut *tx)
    .await?;

    let mut closed = Vec::with_capacity(candidate_ids.len());
    for (session_id,) in candidate_ids {
        let result = sqlx::query(
            "UPDATE sessions
             SET status = 'closed', closed_at = ?, updated_at = ?
             WHERE session_id = ?
               AND status = 'active'
               AND deleted_at IS NULL
               AND julianday(updated_at) < julianday(?)
               AND NOT EXISTS (
                   SELECT 1 FROM collaboration_bindings binding
                   WHERE binding.session_id = sessions.session_id
               )",
        )
        .bind(closed_at)
        .bind(closed_at)
        .bind(&session_id)
        .bind(cutoff)
        .execute(&mut *tx)
        .await?;
        if result.rows_affected() != 1 {
            continue;
        }
        closed.push(
            sqlx::query_as::<_, SessionRow>(
                "SELECT * FROM sessions WHERE session_id = ? AND deleted_at IS NULL",
            )
            .bind(&session_id)
            .fetch_one(&mut *tx)
            .await?
            .into_session(),
        );
    }
    tx.commit().await?;
    Ok(closed)
}

async fn list_session_summaries_from_pool(
    pool: &SqlitePool,
) -> anyhow::Result<Vec<SessionSummary>> {
    let rows = sqlx::query_as::<_, SessionSummaryRow>(
        "SELECT sessions.*,
                EXISTS(
                    SELECT 1
                    FROM collaboration_bindings binding
                    WHERE binding.session_id = sessions.session_id
                ) AS has_collaboration_binding
         FROM sessions
         WHERE sessions.deleted_at IS NULL
         ORDER BY sessions.created_at DESC",
    )
    .fetch_all(pool)
    .await?;
    Ok(rows
        .into_iter()
        .map(SessionSummaryRow::into_summary)
        .collect())
}

pub async fn close_session(session_id: String) -> anyhow::Result<()> {
    let pool = get_db()?;
    let mut tx = pool.begin().await?;
    crate::db::collaboration::mutate_session_in_tx(&mut tx, &session_id, "close", None).await?;
    tx.commit().await?;
    Ok(())
}

/// Reopens a closed, local-only session on this device.
///
/// Collaboration sessions must be reopened through the synchronized API.
/// Other sessions are not ended when this one is resumed.
pub async fn reopen_local_session(session_id: String) -> anyhow::Result<Session> {
    reopen_local_session_from_pool(get_db()?, &session_id).await
}

/// Creates an independent, writable local copy of a collaboration session.
///
/// The source Session, collaboration binding, synchronization queue, conflicts,
/// cached live draft, and offline records are intentionally left untouched.
/// Only materialized, non-deleted logs are copied, each with a new sync id so a
/// later rejoin cannot confuse the local fork with canonical server entities.
pub async fn copy_collaboration_session_to_local(
    session_id: String,
    title: String,
) -> anyhow::Result<Session> {
    copy_collaboration_session_to_local_from_pool(get_db()?, &session_id, &title).await
}

async fn copy_collaboration_session_to_local_from_pool(
    pool: &SqlitePool,
    session_id: &str,
    title: &str,
) -> anyhow::Result<Session> {
    if session_id.trim().is_empty() {
        anyhow::bail!("SESSION_ID_REQUIRED");
    }
    let title = title.trim();
    if title.is_empty() || title.chars().count() > 200 {
        anyhow::bail!("SESSION_TITLE_INVALID");
    }

    let mut tx = pool.begin().await?;
    let source: Option<(Option<String>,)> =
        sqlx::query_as("SELECT deleted_at FROM sessions WHERE session_id = ?")
            .bind(session_id)
            .fetch_optional(&mut *tx)
            .await?;
    let (deleted_at,) = source.ok_or_else(|| anyhow::anyhow!("SESSION_NOT_FOUND"))?;
    if deleted_at.is_some() {
        anyhow::bail!("SESSION_DELETED");
    }

    let binding_count: (i64,) =
        sqlx::query_as("SELECT COUNT(*) FROM collaboration_bindings WHERE session_id = ?")
            .bind(session_id)
            .fetch_one(&mut *tx)
            .await?;
    if binding_count.0 != 1 {
        anyhow::bail!("LOCAL_COPY_COLLABORATION_REQUIRED");
    }

    let local = Session::new(title.to_string());
    sqlx::query(
        "INSERT INTO sessions (session_id, title, status, share_code, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?)",
    )
    .bind(&local.session_id)
    .bind(&local.title)
    .bind(&local.status)
    .bind(&local.share_code)
    .bind(&local.created_at)
    .bind(&local.updated_at)
    .execute(&mut *tx)
    .await?;

    let logs = sqlx::query_as::<_, LocalCopyLogRow>(
        "SELECT time, controller, callsign, rst_sent, rst_rcvd, qth, device,
                power, antenna, height, remarks, created_at, updated_at,
                source_device_id
         FROM logs
         WHERE session_id = ? AND deleted_at IS NULL
         ORDER BY id ASC",
    )
    .bind(session_id)
    .fetch_all(&mut *tx)
    .await?;
    for log in logs {
        sqlx::query(
            "INSERT INTO logs (
                sync_id, session_id, time, controller, callsign,
                rst_sent, rst_rcvd, qth, device, power, antenna, height,
                remarks, created_at, updated_at, source_device_id
             ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        )
        .bind(format!("log-{}", uuid::Uuid::new_v4()))
        .bind(&local.session_id)
        .bind(log.time)
        .bind(log.controller)
        .bind(log.callsign)
        .bind(log.rst_sent)
        .bind(log.rst_rcvd)
        .bind(log.qth)
        .bind(log.device)
        .bind(log.power)
        .bind(log.antenna)
        .bind(log.height)
        .bind(log.remarks)
        .bind(log.created_at)
        .bind(log.updated_at)
        .bind(log.source_device_id)
        .execute(&mut *tx)
        .await?;
    }

    tx.commit().await?;
    Ok(local)
}

/// Replaces a synchronized collaboration session with an independent,
/// writable local session without contacting the collaboration server.
///
/// The replacement receives new session and log identifiers. Once the local
/// replacement is durable, the source session and all of its local replica
/// metadata are removed in the same transaction.
pub async fn convert_collaboration_session_to_local(session_id: String) -> anyhow::Result<Session> {
    convert_collaboration_session_to_local_from_pool(get_db()?, &session_id).await
}

/// Stops synchronization for one collaboration replica on this device.
///
/// The currently materialized, non-deleted logs are preserved in an
/// independent local session with new identifiers. All replica-only state,
/// including pending mutations, conflicts, cached live drafts, and offline
/// records, is discarded. No request or mutation is sent to the server.
pub async fn stop_collaboration_session_locally(session_id: String) -> anyhow::Result<Session> {
    stop_collaboration_session_locally_from_pool(get_db()?, &session_id).await
}

/// Ends a local-only session without changing its identity or records.
/// Collaboration replicas must use the shared lifecycle API. Reject them in
/// this transaction rather than silently detaching and losing pending data.
pub async fn close_session_locally(session_id: String) -> anyhow::Result<Session> {
    close_session_locally_from_pool(get_db()?, &session_id).await
}

async fn stop_collaboration_session_locally_from_pool(
    pool: &SqlitePool,
    session_id: &str,
) -> anyhow::Result<Session> {
    replace_collaboration_session_locally_from_pool(pool, session_id, false).await
}

async fn convert_collaboration_session_to_local_from_pool(
    pool: &SqlitePool,
    session_id: &str,
) -> anyhow::Result<Session> {
    replace_collaboration_session_locally_from_pool(pool, session_id, true).await
}

async fn replace_collaboration_session_locally_from_pool(
    pool: &SqlitePool,
    session_id: &str,
    require_clean_replica: bool,
) -> anyhow::Result<Session> {
    if session_id.trim().is_empty() {
        anyhow::bail!("SESSION_ID_REQUIRED");
    }

    let mut tx = pool.begin().await?;
    let local =
        replace_collaboration_session_locally_in_tx(&mut tx, session_id, require_clean_replica)
            .await?;
    tx.commit().await?;
    Ok(local)
}

async fn replace_collaboration_session_locally_in_tx(
    tx: &mut sqlx::Transaction<'_, sqlx::Sqlite>,
    session_id: &str,
    require_clean_replica: bool,
) -> anyhow::Result<Session> {
    let source: Option<(String, String, Option<String>)> =
        sqlx::query_as("SELECT title, created_at, deleted_at FROM sessions WHERE session_id = ?")
            .bind(session_id)
            .fetch_optional(&mut **tx)
            .await?;
    let (source_title, source_created_at, deleted_at) =
        source.ok_or_else(|| anyhow::anyhow!("SESSION_NOT_FOUND"))?;
    if deleted_at.is_some() {
        anyhow::bail!("SESSION_DELETED");
    }

    let binding_count: (i64,) =
        sqlx::query_as("SELECT COUNT(*) FROM collaboration_bindings WHERE session_id = ?")
            .bind(session_id)
            .fetch_one(&mut **tx)
            .await?;
    if binding_count.0 != 1 {
        anyhow::bail!("LOCAL_CONVERSION_COLLABORATION_REQUIRED");
    }

    if require_clean_replica {
        // A conflict references its outbox mutation, so checking conflicts first
        // keeps the conflict-specific error observable while still requiring the
        // entire outbox to be empty below.
        let open_conflict_count: (i64,) = sqlx::query_as(
            "SELECT COUNT(*) FROM sync_conflicts WHERE session_id = ? AND state = 'open'",
        )
        .bind(session_id)
        .fetch_one(&mut **tx)
        .await?;
        if open_conflict_count.0 != 0 {
            anyhow::bail!("LOCAL_CONVERSION_OPEN_CONFLICTS");
        }

        let outbox_count: (i64,) =
            sqlx::query_as("SELECT COUNT(*) FROM sync_outbox WHERE session_id = ?")
                .bind(session_id)
                .fetch_one(&mut **tx)
                .await?;
        if outbox_count.0 != 0 {
            anyhow::bail!("LOCAL_CONVERSION_SYNC_OUTBOX_NOT_EMPTY");
        }

        let unresolved_offline_count: (i64,) = sqlx::query_as(
            "SELECT COUNT(*)
             FROM collaboration_offline_records
             WHERE session_id = ? AND state IN ('pending', 'submitting', 'reviewing')",
        )
        .bind(session_id)
        .fetch_one(&mut **tx)
        .await?;
        if unresolved_offline_count.0 != 0 {
            anyhow::bail!("LOCAL_CONVERSION_OFFLINE_RECORDS_PENDING");
        }
    }

    let mut local = Session::new(source_title);
    // The replacement is still the same net/check-in event in history and
    // exports. Preserve that event's original start time.
    local.created_at = source_created_at;
    sqlx::query(
        "INSERT INTO sessions (
            session_id, title, status, share_code, created_at, updated_at, closed_at
         ) VALUES (?, ?, ?, ?, ?, ?, ?)",
    )
    .bind(&local.session_id)
    .bind(&local.title)
    .bind(&local.status)
    .bind(&local.share_code)
    .bind(&local.created_at)
    .bind(&local.updated_at)
    .bind(&local.closed_at)
    .execute(&mut **tx)
    .await?;

    let logs = sqlx::query_as::<_, LocalCopyLogRow>(
        "SELECT time, controller, callsign, rst_sent, rst_rcvd, qth, device,
                power, antenna, height, remarks, created_at, updated_at,
                source_device_id
         FROM logs
         WHERE session_id = ? AND deleted_at IS NULL
         ORDER BY id ASC",
    )
    .bind(session_id)
    .fetch_all(&mut **tx)
    .await?;
    for log in logs {
        sqlx::query(
            "INSERT INTO logs (
                sync_id, session_id, time, controller, callsign,
                rst_sent, rst_rcvd, qth, device, power, antenna, height,
                remarks, created_at, updated_at, source_device_id
             ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        )
        .bind(format!("log-{}", uuid::Uuid::new_v4()))
        .bind(&local.session_id)
        .bind(log.time)
        .bind(log.controller)
        .bind(log.callsign)
        .bind(log.rst_sent)
        .bind(log.rst_rcvd)
        .bind(log.qth)
        .bind(log.device)
        .bind(log.power)
        .bind(log.antenna)
        .bind(log.height)
        .bind(log.remarks)
        .bind(log.created_at)
        .bind(log.updated_at)
        .bind(log.source_device_id)
        .execute(&mut **tx)
        .await?;
    }

    // All replica tables cascade from the binding. Logs and the legacy oplog
    // predate foreign keys and are removed explicitly before the source row.
    let deleted_binding = sqlx::query("DELETE FROM collaboration_bindings WHERE session_id = ?")
        .bind(session_id)
        .execute(&mut **tx)
        .await?;
    if deleted_binding.rows_affected() != 1 {
        anyhow::bail!("LOCAL_CONVERSION_BINDING_CHANGED");
    }
    sqlx::query("DELETE FROM logs WHERE session_id = ?")
        .bind(session_id)
        .execute(&mut **tx)
        .await?;
    sqlx::query("DELETE FROM oplog WHERE session_id = ?")
        .bind(session_id)
        .execute(&mut **tx)
        .await?;
    let deleted_session = sqlx::query("DELETE FROM sessions WHERE session_id = ?")
        .bind(session_id)
        .execute(&mut **tx)
        .await?;
    if deleted_session.rows_affected() != 1 {
        anyhow::bail!("LOCAL_CONVERSION_SOURCE_CHANGED");
    }

    Ok(local)
}

async fn close_session_locally_from_pool(
    pool: &SqlitePool,
    session_id: &str,
) -> anyhow::Result<Session> {
    if session_id.trim().is_empty() {
        anyhow::bail!("SESSION_ID_REQUIRED");
    }

    let mut tx = pool.begin().await?;
    let current: Option<(String, Option<String>)> =
        sqlx::query_as("SELECT status, deleted_at FROM sessions WHERE session_id = ?")
            .bind(session_id)
            .fetch_optional(&mut *tx)
            .await?;
    let (status, deleted_at) = current.ok_or_else(|| anyhow::anyhow!("SESSION_NOT_FOUND"))?;
    if deleted_at.is_some() {
        anyhow::bail!("SESSION_DELETED");
    }
    let binding_count: (i64,) =
        sqlx::query_as("SELECT COUNT(*) FROM collaboration_bindings WHERE session_id = ?")
            .bind(session_id)
            .fetch_one(&mut *tx)
            .await?;
    let closed = if binding_count.0 == 1 {
        anyhow::bail!("LOCAL_CLOSE_COLLABORATION_FORBIDDEN");
    } else if binding_count.0 == 0 {
        if status != "active" {
            anyhow::bail!("SESSION_CLOSED");
        }
        let now = chrono::Utc::now().to_rfc3339();
        sqlx::query(
            "UPDATE sessions
             SET status = 'closed', closed_at = ?, updated_at = ?
             WHERE session_id = ?",
        )
        .bind(&now)
        .bind(&now)
        .bind(session_id)
        .execute(&mut *tx)
        .await?;
        sqlx::query_as::<_, SessionRow>(
            "SELECT * FROM sessions WHERE session_id = ? AND deleted_at IS NULL",
        )
        .bind(session_id)
        .fetch_one(&mut *tx)
        .await?
        .into_session()
    } else {
        anyhow::bail!("LOCAL_CONVERSION_BINDING_CHANGED");
    };
    tx.commit().await?;
    Ok(closed)
}

async fn reopen_local_session_from_pool(
    pool: &SqlitePool,
    session_id: &str,
) -> anyhow::Result<Session> {
    if session_id.trim().is_empty() {
        anyhow::bail!("SESSION_ID_REQUIRED");
    }

    let mut tx = pool.begin().await?;
    let session: Option<(String, Option<String>)> =
        sqlx::query_as("SELECT status, deleted_at FROM sessions WHERE session_id = ?")
            .bind(session_id)
            .fetch_optional(&mut *tx)
            .await?;
    let (status, deleted_at) = session.ok_or_else(|| anyhow::anyhow!("SESSION_NOT_FOUND"))?;
    if deleted_at.is_some() {
        anyhow::bail!("SESSION_DELETED");
    }
    if status != "closed" {
        anyhow::bail!("SESSION_NOT_CLOSED");
    }

    let binding_count: (i64,) =
        sqlx::query_as("SELECT COUNT(*) FROM collaboration_bindings WHERE session_id = ?")
            .bind(session_id)
            .fetch_one(&mut *tx)
            .await?;
    if binding_count.0 != 0 {
        anyhow::bail!("LOCAL_REOPEN_COLLABORATION_FORBIDDEN");
    }

    let now = chrono::Utc::now().to_rfc3339();
    sqlx::query(
        "UPDATE sessions
         SET status = 'active', closed_at = NULL, updated_at = ?
         WHERE session_id = ?",
    )
    .bind(&now)
    .bind(session_id)
    .execute(&mut *tx)
    .await?;

    let reopened = sqlx::query_as::<_, SessionRow>(
        "SELECT * FROM sessions WHERE session_id = ? AND deleted_at IS NULL",
    )
    .bind(session_id)
    .fetch_one(&mut *tx)
    .await?
    .into_session();
    tx.commit().await?;
    Ok(reopened)
}

/// Permanently removes a session from this device.
///
/// This is deliberately a local-only operation. Deleting the collaboration
/// binding also cascades through every local replica table, but no mutation is
/// sent to the server and the shared server session is left untouched. Callers
/// that keep a selected-session pointer must clear it before or immediately
/// after deleting that selected row.
pub async fn hard_delete_session(session_id: String) -> anyhow::Result<()> {
    hard_delete_session_from_pool(get_db()?, &session_id).await
}

async fn hard_delete_session_from_pool(pool: &SqlitePool, session_id: &str) -> anyhow::Result<()> {
    if session_id.trim().is_empty() {
        anyhow::bail!("SESSION_ID_REQUIRED");
    }

    let mut tx = pool.begin().await?;
    let session: Option<(i64,)> =
        sqlx::query_as("SELECT 1 FROM sessions WHERE session_id = ? AND deleted_at IS NULL")
            .bind(session_id)
            .fetch_optional(&mut *tx)
            .await?;
    if session.is_none() {
        anyhow::bail!("SESSION_NOT_FOUND");
    }

    // The replica tables all reference collaboration_bindings with ON DELETE
    // CASCADE. Removing the binding first clears shadows, outbox entries,
    // applied events, conflicts, live drafts, and offline records atomically.
    sqlx::query("DELETE FROM collaboration_bindings WHERE session_id = ?")
        .bind(session_id)
        .execute(&mut *tx)
        .await?;
    // logs and the legacy oplog predate foreign keys and need explicit cleanup.
    sqlx::query("DELETE FROM logs WHERE session_id = ?")
        .bind(session_id)
        .execute(&mut *tx)
        .await?;
    sqlx::query("DELETE FROM oplog WHERE session_id = ?")
        .bind(session_id)
        .execute(&mut *tx)
        .await?;
    sqlx::query("DELETE FROM sessions WHERE session_id = ?")
        .bind(session_id)
        .execute(&mut *tx)
        .await?;

    tx.commit().await?;
    Ok(())
}

pub async fn join_session(share_code: String) -> anyhow::Result<Session> {
    let pool = get_db()?;
    let row = sqlx::query_as::<_, SessionRow>(
        "SELECT * FROM sessions WHERE share_code = ? AND deleted_at IS NULL AND status = 'active'",
    )
    .bind(&share_code)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| anyhow::anyhow!("Session not found"))?;
    Ok(row.into_session())
}

pub async fn update_collaboration_session_title(
    session_id: String,
    title: String,
) -> anyhow::Result<()> {
    crate::db::collaboration::update_session_title(get_db()?, &session_id, &title).await
}

pub async fn reopen_collaboration_session(session_id: String) -> anyhow::Result<()> {
    crate::db::collaboration::reopen_session(get_db()?, &session_id).await
}

#[derive(sqlx::FromRow)]
struct SessionRow {
    session_id: String,
    title: String,
    status: String,
    share_code: Option<String>,
    created_at: String,
    updated_at: String,
    closed_at: Option<String>,
    deleted_at: Option<String>,
}

#[derive(sqlx::FromRow)]
struct SessionSummaryRow {
    session_id: String,
    title: String,
    status: String,
    share_code: Option<String>,
    created_at: String,
    updated_at: String,
    closed_at: Option<String>,
    deleted_at: Option<String>,
    has_collaboration_binding: bool,
}

#[derive(sqlx::FromRow)]
struct LocalCopyLogRow {
    time: String,
    controller: String,
    callsign: String,
    rst_sent: Option<String>,
    rst_rcvd: Option<String>,
    qth: Option<String>,
    device: Option<String>,
    power: Option<String>,
    antenna: Option<String>,
    height: Option<String>,
    remarks: Option<String>,
    created_at: String,
    updated_at: String,
    source_device_id: Option<String>,
}

impl SessionRow {
    fn into_session(self) -> Session {
        Session {
            session_id: self.session_id,
            title: self.title,
            status: self.status,
            share_code: self.share_code,
            created_at: self.created_at,
            updated_at: self.updated_at,
            closed_at: self.closed_at,
            deleted_at: self.deleted_at,
        }
    }
}

impl SessionSummaryRow {
    fn into_summary(self) -> SessionSummary {
        SessionSummary {
            session: Session {
                session_id: self.session_id,
                title: self.title,
                status: self.status,
                share_code: self.share_code,
                created_at: self.created_at,
                updated_at: self.updated_at,
                closed_at: self.closed_at,
                deleted_at: self.deleted_at,
            },
            has_collaboration_binding: self.has_collaboration_binding,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{
        close_inactive_local_sessions_from_pool, close_session_locally_from_pool,
        convert_collaboration_session_to_local_from_pool,
        copy_collaboration_session_to_local_from_pool, hard_delete_session_from_pool,
        list_session_summaries_from_pool, reopen_local_session_from_pool,
        start_local_session_from_pool, stop_collaboration_session_locally_from_pool,
        LocalCopyLogRow,
    };
    use crate::db::migrations;
    use sqlx::sqlite::{SqliteConnectOptions, SqlitePoolOptions};
    use sqlx::SqlitePool;
    use std::str::FromStr;

    const NOW: &str = "2026-07-13T08:00:00Z";

    async fn setup() -> SqlitePool {
        let options = SqliteConnectOptions::from_str("sqlite::memory:")
            .unwrap()
            .foreign_keys(true);
        let pool = SqlitePoolOptions::new()
            .max_connections(1)
            .connect_with(options)
            .await
            .unwrap();
        migrations::run(&pool).await.unwrap();
        pool
    }

    async fn insert_session(pool: &SqlitePool, id: &str, status: &str) {
        sqlx::query(
            "INSERT INTO sessions (
                session_id, title, status, created_at, updated_at, closed_at
             ) VALUES (?, ?, ?, ?, ?, ?)",
        )
        .bind(id)
        .bind(format!("Session {id}"))
        .bind(status)
        .bind(NOW)
        .bind(NOW)
        .bind((status != "active").then_some(NOW))
        .execute(pool)
        .await
        .unwrap();
    }

    async fn insert_collaboration_binding(pool: &SqlitePool, session_id: &str) {
        sqlx::query(
            "INSERT INTO collaboration_bindings (
                server_instance_id, server_origin, account_id, session_id,
                membership_id, membership_version, role, replica_state,
                joined_at, updated_at
             ) VALUES (
                'server', 'https://example.test', 'account', ?,
                ?, 1, 'owner', 'ready', ?, ?
             )",
        )
        .bind(session_id)
        .bind(format!("membership-{session_id}"))
        .bind(NOW)
        .bind(NOW)
        .execute(pool)
        .await
        .unwrap();
    }

    async fn insert_dirty_collaboration_replica(pool: &SqlitePool, session_id: &str) {
        insert_collaboration_binding(pool, session_id).await;
        sqlx::query(
            "INSERT INTO logs (
                sync_id, session_id, time, controller, callsign,
                rst_sent, rst_rcvd, qth, device, power, antenna, height,
                remarks, created_at, updated_at, source_device_id
             ) VALUES (
                ?, ?, '2026-07-13T08:01:00Z', 'BG5CRL', 'BA4AAA',
                '59', '57', 'Hangzhou', 'IC-7300', '20W', 'DP', '8m',
                'visible note', '2026-07-13T08:02:00Z',
                '2026-07-13T08:03:00Z', 'device-1'
             )",
        )
        .bind(format!("log-{session_id}"))
        .bind(session_id)
        .execute(pool)
        .await
        .unwrap();
        sqlx::query(
            "INSERT INTO sync_outbox (
                server_instance_id, account_id, session_id, mutation_id,
                entity_type, entity_id, operation, base_version, observed_seq,
                payload_json, state, created_at, updated_at
             ) VALUES (
                'server', 'account', ?, ?, 'log', ?, 'update', 1, 1,
                '{}', 'pending', ?, ?
             )",
        )
        .bind(session_id)
        .bind(format!("mutation-{session_id}"))
        .bind(format!("log-{session_id}"))
        .bind(NOW)
        .bind(NOW)
        .execute(pool)
        .await
        .unwrap();
        sqlx::query(
            "INSERT INTO collaboration_live_drafts (
                server_instance_id, account_id, session_id, draft_id,
                draft_version, remote_json, local_fields_json,
                field_revisions_json, dirty_fields_json, local_updated_at
             ) VALUES (
                'server', 'account', ?, ?, 1, '{}',
                '{\"callsign\":\"BA4BBB\"}', '{}', '[\"callsign\"]', ?
             )",
        )
        .bind(session_id)
        .bind(format!("draft-{session_id}"))
        .bind(NOW)
        .execute(pool)
        .await
        .unwrap();
        sqlx::query(
            "INSERT INTO collaboration_offline_records (
                mutation_id, server_instance_id, account_id, session_id,
                draft_id, expected_draft_version, provisional_ordinal,
                record_json, state, created_at, updated_at
             ) VALUES (
                ?, 'server', 'account', ?, ?, 1, 1, '{}', 'pending', ?, ?
             )",
        )
        .bind(format!("offline-{session_id}"))
        .bind(session_id)
        .bind(format!("draft-{session_id}"))
        .bind(NOW)
        .bind(NOW)
        .execute(pool)
        .await
        .unwrap();
    }

    #[tokio::test]
    async fn start_local_session_preserves_all_existing_session_states() {
        let pool = setup().await;
        insert_session(&pool, "previous-local", "active").await;
        insert_session(&pool, "shared-active", "active").await;
        insert_collaboration_binding(&pool, "shared-active").await;

        let started = start_local_session_from_pool(&pool, " Friday net ")
            .await
            .unwrap();

        assert_eq!(started.title, "Friday net");
        assert_eq!(started.status, "active");
        let states: Vec<(String, String)> =
            sqlx::query_as("SELECT session_id, status FROM sessions ORDER BY session_id")
                .fetch_all(&pool)
                .await
                .unwrap();
        assert!(states.contains(&("previous-local".to_string(), "active".to_string())));
        assert!(states.contains(&("shared-active".to_string(), "active".to_string())));
        assert!(states.contains(&(started.session_id, "active".to_string())));
    }

    #[tokio::test]
    async fn invalid_local_session_start_leaves_current_local_session_active() {
        let pool = setup().await;
        insert_session(&pool, "previous-local", "active").await;

        let error = start_local_session_from_pool(&pool, "   ")
            .await
            .unwrap_err();

        assert!(error.to_string().contains("SESSION_TITLE_INVALID"));
        let status: (String,) =
            sqlx::query_as("SELECT status FROM sessions WHERE session_id = 'previous-local'")
                .fetch_one(&pool)
                .await
                .unwrap();
        assert_eq!(status.0, "active");
    }

    #[tokio::test]
    async fn session_summaries_expose_collaboration_binding_without_hiding_local_rows() {
        let pool = setup().await;
        insert_session(&pool, "local", "closed").await;
        insert_session(&pool, "shared", "active").await;
        insert_collaboration_binding(&pool, "shared").await;

        let summaries = list_session_summaries_from_pool(&pool).await.unwrap();
        let local = summaries
            .iter()
            .find(|summary| summary.session.session_id == "local")
            .unwrap();
        let shared = summaries
            .iter()
            .find(|summary| summary.session.session_id == "shared")
            .unwrap();

        assert!(!local.has_collaboration_binding);
        assert!(shared.has_collaboration_binding);
    }

    #[tokio::test]
    async fn inactivity_sweep_closes_only_local_sessions_older_than_two_hours() {
        let pool = setup().await;
        for id in [
            "stale-local",
            "boundary-local",
            "recent-local",
            "stale-shared",
        ] {
            insert_session(&pool, id, "active").await;
        }
        insert_session(&pool, "already-closed", "closed").await;
        insert_collaboration_binding(&pool, "stale-shared").await;
        for (id, updated_at) in [
            ("stale-local", "2026-07-13T09:59:59Z"),
            ("boundary-local", "2026-07-13T10:00:00Z"),
            ("recent-local", "2026-07-13T10:00:01Z"),
            ("stale-shared", "2026-07-13T09:00:00Z"),
        ] {
            sqlx::query("UPDATE sessions SET updated_at = ? WHERE session_id = ?")
                .bind(updated_at)
                .bind(id)
                .execute(&pool)
                .await
                .unwrap();
        }

        let closed = close_inactive_local_sessions_from_pool(
            &pool,
            "2026-07-13T10:00:00Z",
            "2026-07-13T12:00:00Z",
        )
        .await
        .unwrap();

        assert_eq!(closed.len(), 1);
        assert_eq!(closed[0].session_id, "stale-local");
        assert_eq!(closed[0].status, "closed");
        assert_eq!(closed[0].closed_at.as_deref(), Some("2026-07-13T12:00:00Z"));
        let states: Vec<(String, String)> =
            sqlx::query_as("SELECT session_id, status FROM sessions ORDER BY session_id")
                .fetch_all(&pool)
                .await
                .unwrap();
        assert!(states.contains(&("boundary-local".to_string(), "active".to_string())));
        assert!(states.contains(&("recent-local".to_string(), "active".to_string())));
        assert!(states.contains(&("stale-shared".to_string(), "active".to_string())));
        assert!(states.contains(&("already-closed".to_string(), "closed".to_string())));
    }

    #[tokio::test]
    async fn hard_delete_removes_active_local_and_collaboration_rows_only_on_this_device() {
        let pool = setup().await;
        insert_session(&pool, "active-local", "active").await;
        insert_session(&pool, "active-collaboration", "active").await;
        insert_session(&pool, "unrelated", "closed").await;
        insert_dirty_collaboration_replica(&pool, "active-collaboration").await;

        hard_delete_session_from_pool(&pool, "active-local")
            .await
            .unwrap();
        hard_delete_session_from_pool(&pool, "active-collaboration")
            .await
            .unwrap();

        let remaining: Vec<(String, String)> =
            sqlx::query_as("SELECT session_id, status FROM sessions ORDER BY session_id")
                .fetch_all(&pool)
                .await
                .unwrap();
        assert_eq!(
            remaining,
            vec![("unrelated".to_string(), "closed".to_string())]
        );
        for table in [
            "logs",
            "collaboration_bindings",
            "sync_outbox",
            "collaboration_live_drafts",
            "collaboration_offline_records",
        ] {
            let query = format!("SELECT COUNT(*) FROM {table}");
            let count: (i64,) = sqlx::query_as(&query).fetch_one(&pool).await.unwrap();
            assert_eq!(count.0, 0, "{table} retained deleted replica data");
        }
    }

    #[tokio::test]
    async fn local_stop_discards_dirty_replica_state_and_preserves_saved_log_fields() {
        let pool = setup().await;
        insert_session(&pool, "collaboration-session", "active").await;
        insert_session(&pool, "previous-local", "active").await;
        sqlx::query(
            "UPDATE sessions SET title = 'Sunday net'
             WHERE session_id = 'collaboration-session'",
        )
        .execute(&pool)
        .await
        .unwrap();
        insert_dirty_collaboration_replica(&pool, "collaboration-session").await;

        let local = stop_collaboration_session_locally_from_pool(&pool, "collaboration-session")
            .await
            .unwrap();

        assert_ne!(local.session_id, "collaboration-session");
        assert_eq!(local.title, "Sunday net");
        assert_eq!(local.status, "active");
        assert_eq!(local.created_at, NOW);
        assert_ne!(local.updated_at, NOW);
        let copied = sqlx::query_as::<_, LocalCopyLogRow>(
            "SELECT time, controller, callsign, rst_sent, rst_rcvd, qth, device,
                    power, antenna, height, remarks, created_at, updated_at,
                    source_device_id
             FROM logs WHERE session_id = ?",
        )
        .bind(&local.session_id)
        .fetch_one(&pool)
        .await
        .unwrap();
        assert_eq!(copied.time, "2026-07-13T08:01:00Z");
        assert_eq!(copied.controller, "BG5CRL");
        assert_eq!(copied.callsign, "BA4AAA");
        assert_eq!(copied.rst_sent.as_deref(), Some("59"));
        assert_eq!(copied.rst_rcvd.as_deref(), Some("57"));
        assert_eq!(copied.qth.as_deref(), Some("Hangzhou"));
        assert_eq!(copied.device.as_deref(), Some("IC-7300"));
        assert_eq!(copied.power.as_deref(), Some("20W"));
        assert_eq!(copied.antenna.as_deref(), Some("DP"));
        assert_eq!(copied.height.as_deref(), Some("8m"));
        assert_eq!(copied.remarks.as_deref(), Some("visible note"));
        assert_eq!(copied.created_at, "2026-07-13T08:02:00Z");
        assert_eq!(copied.updated_at, "2026-07-13T08:03:00Z");
        assert_eq!(copied.source_device_id.as_deref(), Some("device-1"));

        let copied_sync_id: String =
            sqlx::query_scalar("SELECT sync_id FROM logs WHERE session_id = ?")
                .bind(&local.session_id)
                .fetch_one(&pool)
                .await
                .unwrap();
        assert_ne!(copied_sync_id, "log-collaboration-session");
        for table in [
            "sessions",
            "logs",
            "collaboration_bindings",
            "sync_outbox",
            "collaboration_live_drafts",
            "collaboration_offline_records",
        ] {
            let query = format!("SELECT COUNT(*) FROM {table} WHERE session_id = ?");
            let count: (i64,) = sqlx::query_as(&query)
                .bind("collaboration-session")
                .fetch_one(&pool)
                .await
                .unwrap();
            assert_eq!(count.0, 0, "{table} retained stopped replica data");
        }
        let replacement_replica_state: (i64, i64, i64, i64) = sqlx::query_as(
            "SELECT
                (SELECT COUNT(*) FROM collaboration_bindings WHERE session_id = ?),
                (SELECT COUNT(*) FROM sync_outbox WHERE session_id = ?),
                (SELECT COUNT(*) FROM collaboration_live_drafts WHERE session_id = ?),
                (SELECT COUNT(*) FROM collaboration_offline_records WHERE session_id = ?)",
        )
        .bind(&local.session_id)
        .bind(&local.session_id)
        .bind(&local.session_id)
        .bind(&local.session_id)
        .fetch_one(&pool)
        .await
        .unwrap();
        assert_eq!(replacement_replica_state, (0, 0, 0, 0));
        let previous_local: (String, Option<String>) = sqlx::query_as(
            "SELECT status, closed_at FROM sessions WHERE session_id = 'previous-local'",
        )
        .fetch_one(&pool)
        .await
        .unwrap();
        assert_eq!(previous_local.0, "active");
        assert_eq!(previous_local.1, None);
    }

    #[tokio::test]
    async fn local_stop_turns_a_closed_replica_into_active_local_recorder() {
        let pool = setup().await;
        insert_session(&pool, "closed-collaboration", "closed").await;
        insert_dirty_collaboration_replica(&pool, "closed-collaboration").await;

        let local = stop_collaboration_session_locally_from_pool(&pool, "closed-collaboration")
            .await
            .unwrap();

        assert_ne!(local.session_id, "closed-collaboration");
        assert_eq!(local.status, "active");
        assert_eq!(local.created_at, NOW);
        assert_eq!(local.closed_at, None);
        let copied_log_count: (i64,) =
            sqlx::query_as("SELECT COUNT(*) FROM logs WHERE session_id = ?")
                .bind(&local.session_id)
                .fetch_one(&pool)
                .await
                .unwrap();
        assert_eq!(copied_log_count.0, 1);
    }

    #[tokio::test]
    async fn local_close_rejects_active_and_closed_replicas_without_losing_data() {
        for status in ["active", "closed"] {
            let pool = setup().await;
            insert_session(&pool, "collaboration-session", status).await;
            insert_session(&pool, "other-local", "active").await;
            insert_dirty_collaboration_replica(&pool, "collaboration-session").await;

            let counts = "SELECT
                (SELECT COUNT(*) FROM sessions),
                (SELECT COUNT(*) FROM logs),
                (SELECT COUNT(*) FROM collaboration_bindings),
                (SELECT COUNT(*) FROM sync_outbox),
                (SELECT COUNT(*) FROM sync_conflicts),
                (SELECT COUNT(*) FROM collaboration_live_drafts),
                (SELECT COUNT(*) FROM collaboration_offline_records)";
            let before: (i64, i64, i64, i64, i64, i64, i64) =
                sqlx::query_as(counts).fetch_one(&pool).await.unwrap();
            assert!(before.2 > 0 && before.3 > 0 && before.5 > 0 && before.6 > 0);
            let error = close_session_locally_from_pool(&pool, "collaboration-session")
                .await
                .unwrap_err();
            assert_eq!(error.to_string(), "LOCAL_CLOSE_COLLABORATION_FORBIDDEN");
            let after: (i64, i64, i64, i64, i64, i64, i64) =
                sqlx::query_as(counts).fetch_one(&pool).await.unwrap();
            assert_eq!(after, before);
            let stored: (String,) = sqlx::query_as(
                "SELECT status FROM sessions WHERE session_id = 'collaboration-session'",
            )
            .fetch_one(&pool)
            .await
            .unwrap();
            assert_eq!(stored.0, status);
            let other: (String,) =
                sqlx::query_as("SELECT status FROM sessions WHERE session_id = 'other-local'")
                    .fetch_one(&pool)
                    .await
                    .unwrap();
            assert_eq!(other.0, "active");
        }
    }

    #[tokio::test]
    async fn local_close_keeps_a_local_only_session_id_and_creates_no_outbox() {
        let pool = setup().await;
        insert_session(&pool, "local-session", "active").await;

        let closed = close_session_locally_from_pool(&pool, "local-session")
            .await
            .unwrap();

        assert_eq!(closed.session_id, "local-session");
        assert_eq!(closed.status, "closed");
        assert!(closed.closed_at.is_some());
        let outbox: (i64,) =
            sqlx::query_as("SELECT COUNT(*) FROM sync_outbox WHERE session_id = 'local-session'")
                .fetch_one(&pool)
                .await
                .unwrap();
        assert_eq!(outbox.0, 0);
    }

    #[tokio::test]
    async fn local_reopen_preserves_other_active_sessions() {
        let pool = setup().await;
        insert_session(&pool, "closed-session", "closed").await;
        insert_session(&pool, "local-active", "active").await;
        insert_session(&pool, "remote-active", "active").await;
        sqlx::query(
            "INSERT INTO collaboration_bindings (
                server_instance_id, server_origin, account_id, session_id,
                membership_id, membership_version, role, replica_state,
                joined_at, updated_at
             ) VALUES (
                'server', 'https://example.test', 'account', 'remote-active',
                'membership', 1, 'owner', 'ready', ?, ?
             )",
        )
        .bind(NOW)
        .bind(NOW)
        .execute(&pool)
        .await
        .unwrap();

        reopen_local_session_from_pool(&pool, "closed-session")
            .await
            .unwrap();

        let reopened: (String, Option<String>, String) = sqlx::query_as(
            "SELECT status, closed_at, updated_at FROM sessions WHERE session_id = ?",
        )
        .bind("closed-session")
        .fetch_one(&pool)
        .await
        .unwrap();
        assert_eq!(reopened.0, "active");
        assert_eq!(reopened.1, None);
        assert_ne!(reopened.2, NOW);

        let local_active: (String, Option<String>) = sqlx::query_as(
            "SELECT status, closed_at FROM sessions WHERE session_id = 'local-active'",
        )
        .fetch_one(&pool)
        .await
        .unwrap();
        assert_eq!(local_active.0, "active");
        assert_eq!(local_active.1, None);

        let remote_active: (String, Option<String>) = sqlx::query_as(
            "SELECT status, closed_at FROM sessions WHERE session_id = 'remote-active'",
        )
        .fetch_one(&pool)
        .await
        .unwrap();
        assert_eq!(remote_active.0, "active");
        assert_eq!(remote_active.1, None);
    }

    #[tokio::test]
    async fn local_reopen_rolls_back_other_session_changes_when_target_update_fails() {
        let pool = setup().await;
        insert_session(&pool, "closed-session", "closed").await;
        insert_session(&pool, "local-active", "active").await;
        sqlx::query(
            "CREATE TRIGGER fail_reopen_target
             BEFORE UPDATE ON sessions
             WHEN OLD.session_id = 'closed-session' AND NEW.status = 'active'
             BEGIN
               SELECT RAISE(ABORT, 'forced reopen failure');
             END",
        )
        .execute(&pool)
        .await
        .unwrap();

        let error = reopen_local_session_from_pool(&pool, "closed-session")
            .await
            .unwrap_err()
            .to_string();

        assert!(error.contains("forced reopen failure"));
        let sessions: Vec<(String, String, Option<String>, String)> = sqlx::query_as(
            "SELECT session_id, status, closed_at, updated_at
             FROM sessions ORDER BY session_id",
        )
        .fetch_all(&pool)
        .await
        .unwrap();
        assert_eq!(
            sessions,
            vec![
                (
                    "closed-session".to_string(),
                    "closed".to_string(),
                    Some(NOW.to_string()),
                    NOW.to_string(),
                ),
                (
                    "local-active".to_string(),
                    "active".to_string(),
                    None,
                    NOW.to_string(),
                ),
            ]
        );
    }

    #[tokio::test]
    async fn local_reopen_rejects_archived_session() {
        let pool = setup().await;
        insert_session(&pool, "archived-session", "archived").await;

        let error = reopen_local_session_from_pool(&pool, "archived-session")
            .await
            .unwrap_err()
            .to_string();

        assert!(error.contains("SESSION_NOT_CLOSED"));
        let session: (String, Option<String>) = sqlx::query_as(
            "SELECT status, closed_at FROM sessions WHERE session_id = 'archived-session'",
        )
        .fetch_one(&pool)
        .await
        .unwrap();
        assert_eq!(session.0, "archived");
        assert!(session.1.is_some());
    }

    #[tokio::test]
    async fn local_reopen_rejects_collaboration_session_without_changes() {
        let pool = setup().await;
        insert_session(&pool, "collaboration-session", "closed").await;
        insert_session(&pool, "local-active", "active").await;
        sqlx::query(
            "INSERT INTO collaboration_bindings (
                server_instance_id, server_origin, account_id, session_id,
                membership_id, membership_version, role, replica_state,
                joined_at, updated_at
             ) VALUES (
                'server', 'https://example.test', 'account', 'collaboration-session',
                'membership', 1, 'owner', 'ready', ?, ?
             )",
        )
        .bind(NOW)
        .bind(NOW)
        .execute(&pool)
        .await
        .unwrap();

        let error = reopen_local_session_from_pool(&pool, "collaboration-session")
            .await
            .unwrap_err()
            .to_string();

        assert!(error.contains("LOCAL_REOPEN_COLLABORATION_FORBIDDEN"));
        let statuses: Vec<(String, String)> =
            sqlx::query_as("SELECT session_id, status FROM sessions ORDER BY session_id")
                .fetch_all(&pool)
                .await
                .unwrap();
        assert_eq!(
            statuses,
            vec![
                ("collaboration-session".to_string(), "closed".to_string()),
                ("local-active".to_string(), "active".to_string()),
            ]
        );
    }

    #[tokio::test]
    async fn local_copy_preserves_collaboration_replica_and_clones_visible_logs() {
        let pool = setup().await;
        insert_session(&pool, "collaboration-session", "active").await;
        insert_session(&pool, "local-active", "active").await;
        sqlx::query(
            "INSERT INTO collaboration_bindings (
                server_instance_id, server_origin, account_id, session_id,
                membership_id, membership_version, role, replica_state,
                joined_at, updated_at
             ) VALUES (
                'server', 'https://example.test', 'account', 'collaboration-session',
                'membership', 1, 'owner', 'ready', ?, ?
             )",
        )
        .bind(NOW)
        .bind(NOW)
        .execute(&pool)
        .await
        .unwrap();
        sqlx::query(
            "INSERT INTO logs (
                sync_id, session_id, time, controller, callsign,
                rst_sent, rst_rcvd, qth, device, power, antenna, height,
                remarks, created_at, updated_at, source_device_id
             ) VALUES (
                'server-log', 'collaboration-session', ?, 'BG5CRL', 'BA4AAA',
                '59', '57', 'Hangzhou', 'IC-7300', '20W', 'DP', '8m',
                'visible note', ?, ?, 'device-1'
             )",
        )
        .bind(NOW)
        .bind(NOW)
        .bind(NOW)
        .execute(&pool)
        .await
        .unwrap();
        sqlx::query(
            "INSERT INTO logs (
                sync_id, session_id, time, controller, callsign,
                created_at, updated_at, deleted_at
             ) VALUES (
                'deleted-log', 'collaboration-session', ?, 'BG5CRL', 'BA4BBB',
                ?, ?, ?
             )",
        )
        .bind(NOW)
        .bind(NOW)
        .bind(NOW)
        .bind(NOW)
        .execute(&pool)
        .await
        .unwrap();
        sqlx::query(
            "INSERT INTO sync_outbox (
                server_instance_id, account_id, session_id, mutation_id,
                entity_type, entity_id, operation, base_version, observed_seq,
                payload_json, state, created_at, updated_at
             ) VALUES (
                'server', 'account', 'collaboration-session', 'pending-mutation',
                'log', 'server-log', 'update', 1, 1, '{}', 'pending', ?, ?
             )",
        )
        .bind(NOW)
        .bind(NOW)
        .execute(&pool)
        .await
        .unwrap();
        sqlx::query(
            "INSERT INTO collaboration_live_drafts (
                server_instance_id, account_id, session_id, draft_id,
                draft_version, remote_json, local_fields_json,
                field_revisions_json, dirty_fields_json, local_updated_at
             ) VALUES (
                'server', 'account', 'collaboration-session', 'draft', 1,
                '{}', '{}', '{}', '[]', ?
             )",
        )
        .bind(NOW)
        .execute(&pool)
        .await
        .unwrap();

        let local = copy_collaboration_session_to_local_from_pool(
            &pool,
            "collaboration-session",
            "Sunday net (local copy)",
        )
        .await
        .unwrap();

        assert_ne!(local.session_id, "collaboration-session");
        assert_eq!(local.title, "Sunday net (local copy)");
        assert_eq!(local.status, "active");
        let source_state: (String, i64, i64, i64) = sqlx::query_as(
            "SELECT sessions.status,
                    (SELECT COUNT(*) FROM collaboration_bindings
                     WHERE session_id = sessions.session_id),
                    (SELECT COUNT(*) FROM sync_outbox
                     WHERE session_id = sessions.session_id),
                    (SELECT COUNT(*) FROM collaboration_live_drafts
                     WHERE session_id = sessions.session_id)
             FROM sessions WHERE session_id = 'collaboration-session'",
        )
        .fetch_one(&pool)
        .await
        .unwrap();
        assert_eq!(source_state, ("active".to_string(), 1, 1, 1));

        let previous_local: (String, Option<String>) = sqlx::query_as(
            "SELECT status, closed_at FROM sessions WHERE session_id = 'local-active'",
        )
        .fetch_one(&pool)
        .await
        .unwrap();
        assert_eq!(previous_local.0, "active");
        assert_eq!(previous_local.1, None);

        let local_binding_count: (i64,) =
            sqlx::query_as("SELECT COUNT(*) FROM collaboration_bindings WHERE session_id = ?")
                .bind(&local.session_id)
                .fetch_one(&pool)
                .await
                .unwrap();
        assert_eq!(local_binding_count.0, 0);
        let copied: Vec<(
            String,
            String,
            String,
            Option<String>,
            Option<String>,
            Option<String>,
            Option<String>,
            Option<String>,
            Option<String>,
            Option<String>,
            Option<String>,
        )> = sqlx::query_as(
            "SELECT sync_id, controller, callsign, rst_sent, rst_rcvd, qth,
                    device, power, antenna, height, remarks
             FROM logs WHERE session_id = ? ORDER BY id",
        )
        .bind(&local.session_id)
        .fetch_all(&pool)
        .await
        .unwrap();
        assert_eq!(copied.len(), 1);
        assert_ne!(copied[0].0, "server-log");
        assert_eq!(copied[0].1, "BG5CRL");
        assert_eq!(copied[0].2, "BA4AAA");
        assert_eq!(copied[0].3.as_deref(), Some("59"));
        assert_eq!(copied[0].4.as_deref(), Some("57"));
        assert_eq!(copied[0].5.as_deref(), Some("Hangzhou"));
        assert_eq!(copied[0].6.as_deref(), Some("IC-7300"));
        assert_eq!(copied[0].7.as_deref(), Some("20W"));
        assert_eq!(copied[0].8.as_deref(), Some("DP"));
        assert_eq!(copied[0].9.as_deref(), Some("8m"));
        assert_eq!(copied[0].10.as_deref(), Some("visible note"));
    }

    #[tokio::test]
    async fn local_conversion_replaces_source_and_preserves_visible_log_fields() {
        let pool = setup().await;
        insert_session(&pool, "collaboration-session", "active").await;
        insert_session(&pool, "local-active", "active").await;
        insert_session(&pool, "remote-active", "active").await;
        sqlx::query(
            "UPDATE sessions SET title = 'Sunday net' WHERE session_id = 'collaboration-session'",
        )
        .execute(&pool)
        .await
        .unwrap();
        insert_collaboration_binding(&pool, "collaboration-session").await;
        insert_collaboration_binding(&pool, "remote-active").await;

        sqlx::query(
            "INSERT INTO logs (
                sync_id, session_id, time, controller, callsign,
                rst_sent, rst_rcvd, qth, device, power, antenna, height,
                remarks, created_at, updated_at, source_device_id
             ) VALUES (
                'server-log', 'collaboration-session', ?, 'BG5CRL', 'BA4AAA',
                '59', '57', 'Hangzhou', 'IC-7300', '20W', 'DP', '8m',
                'visible note', ?, ?, 'device-1'
             )",
        )
        .bind("2026-07-13T08:01:00Z")
        .bind("2026-07-13T08:02:00Z")
        .bind("2026-07-13T08:03:00Z")
        .execute(&pool)
        .await
        .unwrap();
        sqlx::query(
            "INSERT INTO logs (
                sync_id, session_id, time, controller, callsign,
                created_at, updated_at, deleted_at
             ) VALUES (
                'deleted-log', 'collaboration-session', ?, 'BG5CRL', 'BA4BBB',
                ?, ?, ?
             )",
        )
        .bind(NOW)
        .bind(NOW)
        .bind(NOW)
        .bind(NOW)
        .execute(&pool)
        .await
        .unwrap();
        sqlx::query(
            "INSERT INTO oplog (
                session_id, op_type, entity_type, entity_id, data, created_at
             ) VALUES (
                'collaboration-session', 'update', 'log', 'server-log', '{}', ?
             )",
        )
        .bind(NOW)
        .execute(&pool)
        .await
        .unwrap();
        sqlx::query(
            "INSERT INTO entity_shadows (
                server_instance_id, account_id, session_id, entity_type,
                entity_id, server_version, last_event_seq, server_json
             ) VALUES (
                'server', 'account', 'collaboration-session', 'session',
                'collaboration-session', 1, 1, '{}'
             )",
        )
        .execute(&pool)
        .await
        .unwrap();
        sqlx::query(
            "INSERT INTO applied_events (
                server_instance_id, account_id, session_id, event_id,
                event_seq, mutation_id, applied_at
             ) VALUES (
                'server', 'account', 'collaboration-session', 'event', 1, NULL, ?
             )",
        )
        .bind(NOW)
        .execute(&pool)
        .await
        .unwrap();
        sqlx::query(
            "INSERT INTO collaboration_live_drafts (
                server_instance_id, account_id, session_id, draft_id,
                draft_version, remote_json, local_fields_json,
                field_revisions_json, dirty_fields_json, local_updated_at
             ) VALUES (
                'server', 'account', 'collaboration-session', 'draft', 1,
                '{}', '{}', '{}', '[]', ?
             )",
        )
        .bind(NOW)
        .execute(&pool)
        .await
        .unwrap();
        sqlx::query(
            "INSERT INTO collaboration_offline_records (
                mutation_id, server_instance_id, account_id, session_id,
                draft_id, expected_draft_version, provisional_ordinal,
                record_json, state, resolution, created_at, updated_at
             ) VALUES (
                'resolved-offline', 'server', 'account', 'collaboration-session',
                'draft', 1, 1, '{}', 'resolved', 'discard', ?, ?
             )",
        )
        .bind(NOW)
        .bind(NOW)
        .execute(&pool)
        .await
        .unwrap();

        let local =
            convert_collaboration_session_to_local_from_pool(&pool, "collaboration-session")
                .await
                .unwrap();

        assert_ne!(local.session_id, "collaboration-session");
        assert_eq!(local.title, "Sunday net");
        assert_eq!(local.status, "active");
        assert_eq!(local.closed_at, None);
        assert_eq!(local.deleted_at, None);

        let stored_local: (String, String, Option<String>, Option<String>) = sqlx::query_as(
            "SELECT title, status, closed_at, deleted_at FROM sessions WHERE session_id = ?",
        )
        .bind(&local.session_id)
        .fetch_one(&pool)
        .await
        .unwrap();
        assert_eq!(
            stored_local,
            ("Sunday net".to_string(), "active".to_string(), None, None)
        );

        let copied_sync_ids: Vec<String> =
            sqlx::query_scalar("SELECT sync_id FROM logs WHERE session_id = ? ORDER BY id")
                .bind(&local.session_id)
                .fetch_all(&pool)
                .await
                .unwrap();
        assert_eq!(copied_sync_ids.len(), 1);
        assert_ne!(copied_sync_ids[0], "server-log");
        assert_ne!(copied_sync_ids[0], "deleted-log");
        let copied_logs = sqlx::query_as::<_, LocalCopyLogRow>(
            "SELECT time, controller, callsign, rst_sent, rst_rcvd, qth, device,
                    power, antenna, height, remarks, created_at, updated_at,
                    source_device_id
             FROM logs WHERE session_id = ? ORDER BY id",
        )
        .bind(&local.session_id)
        .fetch_all(&pool)
        .await
        .unwrap();
        assert_eq!(copied_logs.len(), 1);
        let copied = &copied_logs[0];
        assert_eq!(copied.time, "2026-07-13T08:01:00Z");
        assert_eq!(copied.controller, "BG5CRL");
        assert_eq!(copied.callsign, "BA4AAA");
        assert_eq!(copied.rst_sent.as_deref(), Some("59"));
        assert_eq!(copied.rst_rcvd.as_deref(), Some("57"));
        assert_eq!(copied.qth.as_deref(), Some("Hangzhou"));
        assert_eq!(copied.device.as_deref(), Some("IC-7300"));
        assert_eq!(copied.power.as_deref(), Some("20W"));
        assert_eq!(copied.antenna.as_deref(), Some("DP"));
        assert_eq!(copied.height.as_deref(), Some("8m"));
        assert_eq!(copied.remarks.as_deref(), Some("visible note"));
        assert_eq!(copied.created_at, "2026-07-13T08:02:00Z");
        assert_eq!(copied.updated_at, "2026-07-13T08:03:00Z");
        assert_eq!(copied.source_device_id.as_deref(), Some("device-1"));

        for table in [
            "sessions",
            "logs",
            "oplog",
            "collaboration_bindings",
            "entity_shadows",
            "sync_outbox",
            "applied_events",
            "sync_conflicts",
            "collaboration_live_drafts",
            "collaboration_offline_records",
        ] {
            let query = format!("SELECT COUNT(*) FROM {table} WHERE session_id = ?");
            let count: (i64,) = sqlx::query_as(&query)
                .bind("collaboration-session")
                .fetch_one(&pool)
                .await
                .unwrap();
            assert_eq!(count.0, 0, "{table} still contains source data");
        }
        let local_binding_count: (i64,) =
            sqlx::query_as("SELECT COUNT(*) FROM collaboration_bindings WHERE session_id = ?")
                .bind(&local.session_id)
                .fetch_one(&pool)
                .await
                .unwrap();
        assert_eq!(local_binding_count.0, 0);

        let local_active: (String, Option<String>) = sqlx::query_as(
            "SELECT status, closed_at FROM sessions WHERE session_id = 'local-active'",
        )
        .fetch_one(&pool)
        .await
        .unwrap();
        assert_eq!(local_active.0, "active");
        assert_eq!(local_active.1, None);
        let remote_active: (String, Option<String>) = sqlx::query_as(
            "SELECT status, closed_at FROM sessions WHERE session_id = 'remote-active'",
        )
        .fetch_one(&pool)
        .await
        .unwrap();
        assert_eq!(remote_active, ("active".to_string(), None));
    }

    #[tokio::test]
    async fn local_conversion_rejects_nonempty_outbox_without_changes() {
        let pool = setup().await;
        insert_session(&pool, "collaboration-session", "active").await;
        insert_session(&pool, "local-active", "active").await;
        insert_collaboration_binding(&pool, "collaboration-session").await;
        sqlx::query(
            "INSERT INTO logs (
                sync_id, session_id, time, controller, callsign, created_at, updated_at
             ) VALUES (
                'server-log', 'collaboration-session', ?, 'BG5CRL', 'BA4AAA', ?, ?
             )",
        )
        .bind(NOW)
        .bind(NOW)
        .bind(NOW)
        .execute(&pool)
        .await
        .unwrap();
        sqlx::query(
            "INSERT INTO sync_outbox (
                server_instance_id, account_id, session_id, mutation_id,
                entity_type, entity_id, operation, base_version, observed_seq,
                payload_json, state, created_at, updated_at
             ) VALUES (
                'server', 'account', 'collaboration-session', 'pending-mutation',
                'log', 'server-log', 'update', 1, 1, '{}', 'pending', ?, ?
             )",
        )
        .bind(NOW)
        .bind(NOW)
        .execute(&pool)
        .await
        .unwrap();

        let error =
            convert_collaboration_session_to_local_from_pool(&pool, "collaboration-session")
                .await
                .unwrap_err()
                .to_string();

        assert_eq!(error, "LOCAL_CONVERSION_SYNC_OUTBOX_NOT_EMPTY");
        let sessions: Vec<(String, String, Option<String>)> = sqlx::query_as(
            "SELECT session_id, status, closed_at FROM sessions ORDER BY session_id",
        )
        .fetch_all(&pool)
        .await
        .unwrap();
        assert_eq!(
            sessions,
            vec![
                (
                    "collaboration-session".to_string(),
                    "active".to_string(),
                    None
                ),
                ("local-active".to_string(), "active".to_string(), None),
            ]
        );
        for (table, expected) in [
            ("sessions", 1_i64),
            ("logs", 1),
            ("collaboration_bindings", 1),
            ("sync_outbox", 1),
        ] {
            let query = format!("SELECT COUNT(*) FROM {table} WHERE session_id = ?");
            let count: (i64,) = sqlx::query_as(&query)
                .bind("collaboration-session")
                .fetch_one(&pool)
                .await
                .unwrap();
            assert_eq!(count.0, expected, "{table} changed after rejection");
        }
    }

    #[tokio::test]
    async fn local_conversion_rejects_unresolved_offline_records_without_changes() {
        for state in ["pending", "submitting", "reviewing"] {
            let pool = setup().await;
            insert_session(&pool, "collaboration-session", "active").await;
            insert_session(&pool, "local-active", "active").await;
            insert_collaboration_binding(&pool, "collaboration-session").await;
            sqlx::query(
                "INSERT INTO collaboration_offline_records (
                    mutation_id, server_instance_id, account_id, session_id,
                    draft_id, expected_draft_version, provisional_ordinal,
                    record_json, state, created_at, updated_at
                 ) VALUES (
                    'offline-mutation', 'server', 'account', 'collaboration-session',
                    'draft', 1, 1, '{}', ?, ?, ?
                 )",
            )
            .bind(state)
            .bind(NOW)
            .bind(NOW)
            .execute(&pool)
            .await
            .unwrap();

            let error =
                convert_collaboration_session_to_local_from_pool(&pool, "collaboration-session")
                    .await
                    .unwrap_err()
                    .to_string();

            assert_eq!(error, "LOCAL_CONVERSION_OFFLINE_RECORDS_PENDING");
            let sessions: Vec<(String, String, Option<String>)> = sqlx::query_as(
                "SELECT session_id, status, closed_at FROM sessions ORDER BY session_id",
            )
            .fetch_all(&pool)
            .await
            .unwrap();
            assert_eq!(
                sessions,
                vec![
                    (
                        "collaboration-session".to_string(),
                        "active".to_string(),
                        None
                    ),
                    ("local-active".to_string(), "active".to_string(), None),
                ],
                "sessions changed for offline state {state}"
            );
            let replica_counts: (i64, i64) = sqlx::query_as(
                "SELECT
                    (SELECT COUNT(*) FROM collaboration_bindings
                     WHERE session_id = 'collaboration-session'),
                    (SELECT COUNT(*) FROM collaboration_offline_records
                     WHERE session_id = 'collaboration-session')",
            )
            .fetch_one(&pool)
            .await
            .unwrap();
            assert_eq!(replica_counts, (1, 1), "replica changed for state {state}");
        }
    }

    #[tokio::test]
    async fn local_conversion_rejects_open_conflict_without_changes() {
        let pool = setup().await;
        insert_session(&pool, "collaboration-session", "active").await;
        insert_session(&pool, "local-active", "active").await;
        insert_collaboration_binding(&pool, "collaboration-session").await;
        sqlx::query(
            "INSERT INTO sync_outbox (
                server_instance_id, account_id, session_id, mutation_id,
                entity_type, entity_id, operation, base_version, observed_seq,
                payload_json, state, created_at, updated_at
             ) VALUES (
                'server', 'account', 'collaboration-session', 'conflict-mutation',
                'session', 'collaboration-session', 'update', 1, 1,
                '{}', 'conflict', ?, ?
             )",
        )
        .bind(NOW)
        .bind(NOW)
        .execute(&pool)
        .await
        .unwrap();
        sqlx::query(
            "INSERT INTO sync_conflicts (
                conflict_id, server_instance_id, account_id, session_id,
                entity_type, entity_id, mutation_id, base_version,
                remote_version, local_json, remote_json,
                conflicting_fields_json, state, created_at
             ) VALUES (
                'conflict', 'server', 'account', 'collaboration-session',
                'session', 'collaboration-session', 'conflict-mutation', 1, 2,
                '{}', '{}', '[]', 'open', ?
             )",
        )
        .bind(NOW)
        .execute(&pool)
        .await
        .unwrap();

        let error =
            convert_collaboration_session_to_local_from_pool(&pool, "collaboration-session")
                .await
                .unwrap_err()
                .to_string();

        assert_eq!(error, "LOCAL_CONVERSION_OPEN_CONFLICTS");
        let statuses: Vec<(String, String)> =
            sqlx::query_as("SELECT session_id, status FROM sessions ORDER BY session_id")
                .fetch_all(&pool)
                .await
                .unwrap();
        assert_eq!(
            statuses,
            vec![
                ("collaboration-session".to_string(), "active".to_string()),
                ("local-active".to_string(), "active".to_string()),
            ]
        );
        let replica_counts: (i64, i64, i64) = sqlx::query_as(
            "SELECT
                (SELECT COUNT(*) FROM collaboration_bindings
                 WHERE session_id = 'collaboration-session'),
                (SELECT COUNT(*) FROM sync_outbox
                 WHERE session_id = 'collaboration-session'),
                (SELECT COUNT(*) FROM sync_conflicts
                 WHERE session_id = 'collaboration-session')",
        )
        .fetch_one(&pool)
        .await
        .unwrap();
        assert_eq!(replica_counts, (1, 1, 1));
    }

    #[tokio::test]
    async fn hard_delete_removes_closed_session_logs_and_replica_state() {
        let pool = setup().await;
        insert_session(&pool, "closed-session", "closed").await;
        insert_session(&pool, "other-session", "active").await;

        sqlx::query(
            "INSERT INTO logs (
                sync_id, session_id, time, controller, callsign,
                created_at, updated_at
             ) VALUES ('closed-log', 'closed-session', ?, 'BG5CRL', 'BA4AAA', ?, ?)",
        )
        .bind(NOW)
        .bind(NOW)
        .bind(NOW)
        .execute(&pool)
        .await
        .unwrap();
        sqlx::query(
            "INSERT INTO oplog (
                session_id, op_type, entity_type, entity_id, data, created_at
             ) VALUES ('closed-session', 'update', 'log', 'closed-log', '{}', ?)",
        )
        .bind(NOW)
        .execute(&pool)
        .await
        .unwrap();
        sqlx::query(
            "INSERT INTO collaboration_bindings (
                server_instance_id, server_origin, account_id, session_id,
                membership_id, membership_version, role, replica_state,
                joined_at, updated_at
             ) VALUES (
                'server', 'https://example.test', 'account', 'closed-session',
                'membership', 1, 'editor', 'ready', ?, ?
             )",
        )
        .bind(NOW)
        .bind(NOW)
        .execute(&pool)
        .await
        .unwrap();
        sqlx::query(
            "INSERT INTO entity_shadows (
                server_instance_id, account_id, session_id, entity_type,
                entity_id, server_version, last_event_seq, server_json
             ) VALUES (
                'server', 'account', 'closed-session', 'session',
                'closed-session', 1, 1, '{}'
             )",
        )
        .execute(&pool)
        .await
        .unwrap();
        sqlx::query(
            "INSERT INTO sync_outbox (
                server_instance_id, account_id, session_id, mutation_id,
                entity_type, entity_id, operation, base_version, observed_seq,
                payload_json, state, created_at, updated_at
             ) VALUES (
                'server', 'account', 'closed-session', 'mutation',
                'session', 'closed-session', 'close', 1, 1,
                '{}', 'conflict', ?, ?
             )",
        )
        .bind(NOW)
        .bind(NOW)
        .execute(&pool)
        .await
        .unwrap();
        sqlx::query(
            "INSERT INTO applied_events (
                server_instance_id, account_id, session_id, event_id,
                event_seq, mutation_id, applied_at
             ) VALUES (
                'server', 'account', 'closed-session', 'event', 1, NULL, ?
             )",
        )
        .bind(NOW)
        .execute(&pool)
        .await
        .unwrap();
        sqlx::query(
            "INSERT INTO sync_conflicts (
                conflict_id, server_instance_id, account_id, session_id,
                entity_type, entity_id, mutation_id, base_version,
                remote_version, local_json, remote_json,
                conflicting_fields_json, state, created_at
             ) VALUES (
                'conflict', 'server', 'account', 'closed-session',
                'session', 'closed-session', 'mutation', 1, 2,
                '{}', '{}', '[]', 'open', ?
             )",
        )
        .bind(NOW)
        .execute(&pool)
        .await
        .unwrap();
        sqlx::query(
            "INSERT INTO collaboration_live_drafts (
                server_instance_id, account_id, session_id, draft_id,
                draft_version, remote_json, local_fields_json,
                field_revisions_json, dirty_fields_json, local_updated_at
             ) VALUES (
                'server', 'account', 'closed-session', 'draft', 1,
                '{}', '{}', '{}', '[]', ?
             )",
        )
        .bind(NOW)
        .execute(&pool)
        .await
        .unwrap();
        sqlx::query(
            "INSERT INTO collaboration_offline_records (
                mutation_id, server_instance_id, account_id, session_id,
                draft_id, expected_draft_version, provisional_ordinal,
                record_json, state, created_at, updated_at
             ) VALUES (
                'offline-mutation', 'server', 'account', 'closed-session',
                'draft', 1, 1, '{}', 'pending', ?, ?
             )",
        )
        .bind(NOW)
        .bind(NOW)
        .execute(&pool)
        .await
        .unwrap();

        hard_delete_session_from_pool(&pool, "closed-session")
            .await
            .unwrap();

        for table in [
            "sessions",
            "logs",
            "oplog",
            "collaboration_bindings",
            "entity_shadows",
            "sync_outbox",
            "applied_events",
            "sync_conflicts",
            "collaboration_live_drafts",
            "collaboration_offline_records",
        ] {
            let query = format!("SELECT COUNT(*) FROM {table} WHERE session_id = ?");
            let count: (i64,) = sqlx::query_as(&query)
                .bind("closed-session")
                .fetch_one(&pool)
                .await
                .unwrap();
            assert_eq!(count.0, 0, "{table} still contains session data");
        }
        let other_count: (i64,) =
            sqlx::query_as("SELECT COUNT(*) FROM sessions WHERE session_id = 'other-session'")
                .fetch_one(&pool)
                .await
                .unwrap();
        assert_eq!(other_count.0, 1);
    }
}
