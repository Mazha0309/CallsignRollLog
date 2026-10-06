//! Callsign Roll Log's serialized SQLite facade.
//!
//! The public surface intentionally mirrors the small SQLx subset used by the
//! existing data core. The implementation is synchronous rusqlite guarded by a
//! single async mutex. On Web, rusqlite is linked to sqlite-wasm-rs and a
//! persistent browser VFS is installed before the connection is opened.

use rusqlite::types::{FromSql, ToSql, ToSqlOutput, Value, ValueRef};
use rusqlite::{params_from_iter, Connection, OpenFlags};
use std::fmt;
use std::marker::PhantomData;
use std::ops::{Deref, DerefMut};
use std::str::FromStr;
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::{Mutex, OwnedMutexGuard};

pub use openlogtool_sqlite_macros::FromRow;

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error(transparent)]
    Database(#[from] rusqlite::Error),
    #[error("{0}")]
    Configuration(String),
}

pub type Result<T> = std::result::Result<T, Error>;

#[derive(Debug, Clone, Copy, Default)]
pub struct Sqlite;

#[derive(Clone)]
pub struct SqlitePool {
    inner: Arc<Mutex<Connection>>,
}

impl fmt::Debug for SqlitePool {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("SqlitePool")
            .field("max_connections", &1)
            .finish()
    }
}

impl SqlitePool {
    pub async fn connect_with(options: sqlite::SqliteConnectOptions) -> Result<Self> {
        let connection = open_connection(&options)?;
        Ok(Self {
            inner: Arc::new(Mutex::new(connection)),
        })
    }

    pub async fn begin(&self) -> Result<Transaction<'_, Sqlite>> {
        self.begin_with("BEGIN").await
    }

    pub async fn begin_with(&self, statement: &str) -> Result<Transaction<'_, Sqlite>> {
        let connection = self.inner.clone().lock_owned().await;
        connection.execute_batch(statement)?;
        Ok(Transaction {
            connection: Some(connection),
            completed: false,
            _database: PhantomData,
            _pool: PhantomData,
        })
    }

    /// Kept for source compatibility. The process-global application pool
    /// stays alive for the application's lifetime; test databases are released
    /// when their pool value is dropped.
    pub async fn close(&self) {}
}

fn open_connection(options: &sqlite::SqliteConnectOptions) -> Result<Connection> {
    let connection = if options.in_memory {
        Connection::open_in_memory()?
    } else {
        let flags = if options.create_if_missing {
            OpenFlags::SQLITE_OPEN_READ_WRITE | OpenFlags::SQLITE_OPEN_CREATE
        } else {
            OpenFlags::SQLITE_OPEN_READ_WRITE
        };
        Connection::open_with_flags(&options.path, flags)?
    };

    connection.busy_timeout(Duration::from_secs(5))?;
    if options.foreign_keys {
        connection.execute_batch("PRAGMA foreign_keys = ON;")?;
    }

    #[cfg(target_arch = "wasm32")]
    {
        if web_uses_relaxed_idb() {
            // relaxed-idb persists commits asynchronously and intentionally
            // supports only synchronous=OFF.
            connection.execute_batch(
                "PRAGMA journal_mode = DELETE;
                 PRAGMA synchronous = OFF;
                 PRAGMA page_size = 65536;",
            )?;
        } else if matches!(options.journal_mode, sqlite::SqliteJournalMode::Wal) {
            connection.execute_batch("PRAGMA journal_mode = WAL;")?;
        }
    }

    #[cfg(not(target_arch = "wasm32"))]
    if matches!(options.journal_mode, sqlite::SqliteJournalMode::Wal) {
        connection.execute_batch("PRAGMA journal_mode = WAL;")?;
    }

    Ok(connection)
}

pub struct Transaction<'pool, DB = Sqlite> {
    connection: Option<OwnedMutexGuard<Connection>>,
    completed: bool,
    _database: PhantomData<DB>,
    _pool: PhantomData<&'pool SqlitePool>,
}

impl<DB> fmt::Debug for Transaction<'_, DB> {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("Transaction")
            .field("completed", &self.completed)
            .finish()
    }
}

impl<DB> Transaction<'_, DB> {
    pub async fn commit(mut self) -> Result<()> {
        self.connection
            .as_ref()
            .expect("transaction connection")
            .execute_batch("COMMIT")?;
        self.completed = true;
        Ok(())
    }

    pub async fn rollback(mut self) -> Result<()> {
        self.connection
            .as_ref()
            .expect("transaction connection")
            .execute_batch("ROLLBACK")?;
        self.completed = true;
        Ok(())
    }
}

impl<DB> Deref for Transaction<'_, DB> {
    type Target = Connection;

    fn deref(&self) -> &Self::Target {
        self.connection
            .as_deref()
            .expect("transaction connection is available")
    }
}

impl<DB> DerefMut for Transaction<'_, DB> {
    fn deref_mut(&mut self) -> &mut Self::Target {
        self.connection
            .as_deref_mut()
            .expect("transaction connection is available")
    }
}

impl<DB> Drop for Transaction<'_, DB> {
    fn drop(&mut self) {
        if !self.completed {
            if let Some(connection) = self.connection.as_ref() {
                let _ = connection.execute_batch("ROLLBACK");
            }
        }
    }
}

#[doc(hidden)]
pub enum ExecutorRef<'executor> {
    Pool(&'executor SqlitePool),
    Connection(&'executor mut Connection),
}

pub trait IntoExecutor<'executor> {
    type Database;

    fn into_executor(self) -> ExecutorRef<'executor>;
}

impl<'executor> IntoExecutor<'executor> for &'executor SqlitePool {
    type Database = Sqlite;

    fn into_executor(self) -> ExecutorRef<'executor> {
        ExecutorRef::Pool(self)
    }
}

impl<'executor> IntoExecutor<'executor> for &'executor mut Connection {
    type Database = Sqlite;

    fn into_executor(self) -> ExecutorRef<'executor> {
        ExecutorRef::Connection(self)
    }
}

#[derive(Debug, Clone)]
enum OwnedValue {
    Null,
    Integer(i64),
    Real(f64),
    Text(Vec<u8>),
    Blob(Vec<u8>),
}

impl OwnedValue {
    fn from_ref(value: ValueRef<'_>) -> Self {
        match value {
            ValueRef::Null => Self::Null,
            ValueRef::Integer(value) => Self::Integer(value),
            ValueRef::Real(value) => Self::Real(value),
            ValueRef::Text(value) => Self::Text(value.to_vec()),
            ValueRef::Blob(value) => Self::Blob(value.to_vec()),
        }
    }

    fn as_ref(&self) -> ValueRef<'_> {
        match self {
            Self::Null => ValueRef::Null,
            Self::Integer(value) => ValueRef::Integer(*value),
            Self::Real(value) => ValueRef::Real(*value),
            Self::Text(value) => ValueRef::Text(value),
            Self::Blob(value) => ValueRef::Blob(value),
        }
    }

    fn type_name(&self) -> &'static str {
        match self {
            Self::Null => "NULL",
            Self::Integer(_) => "INTEGER",
            Self::Real(_) => "REAL",
            Self::Text(_) => "TEXT",
            Self::Blob(_) => "BLOB",
        }
    }
}

pub mod sqlite {
    use super::*;

    #[derive(Debug, Clone, Copy, Default)]
    pub enum SqliteJournalMode {
        #[default]
        Delete,
        Wal,
    }

    #[derive(Debug, Clone)]
    pub struct SqliteConnectOptions {
        pub(crate) path: String,
        pub(crate) in_memory: bool,
        pub(crate) create_if_missing: bool,
        pub(crate) foreign_keys: bool,
        pub(crate) journal_mode: SqliteJournalMode,
    }

    impl FromStr for SqliteConnectOptions {
        type Err = Error;

        fn from_str(value: &str) -> Result<Self> {
            let in_memory = matches!(value, "sqlite::memory:" | ":memory:");
            let path = if in_memory {
                ":memory:".to_string()
            } else if let Some(path) = value.strip_prefix("sqlite://") {
                path.to_string()
            } else if let Some(path) = value.strip_prefix("file:") {
                path.to_string()
            } else if let Some(path) = value.strip_prefix("sqlite:") {
                path.trim_start_matches("//").to_string()
            } else {
                value.to_string()
            };
            if !in_memory && path.trim().is_empty() {
                return Err(Error::Configuration(
                    "SQLite database path must not be empty".to_string(),
                ));
            }
            Ok(Self {
                path,
                in_memory,
                create_if_missing: false,
                foreign_keys: false,
                journal_mode: SqliteJournalMode::Delete,
            })
        }
    }

    impl SqliteConnectOptions {
        pub fn create_if_missing(mut self, enabled: bool) -> Self {
            self.create_if_missing = enabled;
            self
        }

        pub fn foreign_keys(mut self, enabled: bool) -> Self {
            self.foreign_keys = enabled;
            self
        }

        pub fn journal_mode(mut self, mode: SqliteJournalMode) -> Self {
            self.journal_mode = mode;
            self
        }
    }

    #[derive(Debug, Clone, Default)]
    pub struct SqlitePoolOptions {
        max_connections: u32,
    }

    impl SqlitePoolOptions {
        pub fn new() -> Self {
            Self { max_connections: 1 }
        }

        pub fn max_connections(mut self, max_connections: u32) -> Self {
            self.max_connections = max_connections;
            self
        }

        pub async fn connect_with(self, options: SqliteConnectOptions) -> Result<SqlitePool> {
            if self.max_connections != 1 {
                return Err(Error::Configuration(
                    "Callsign Roll Log SQLite storage requires max_connections(1)".to_string(),
                ));
            }
            SqlitePool::connect_with(options).await
        }

        pub async fn connect(self, value: &str) -> Result<SqlitePool> {
            let options = SqliteConnectOptions::from_str(value)?.create_if_missing(true);
            self.connect_with(options).await
        }
    }

    #[derive(Debug, Clone)]
    pub struct SqliteArguments<'query>(pub(crate) PhantomData<&'query ()>);

    #[derive(Debug, Clone)]
    pub struct SqliteTypeInfo {
        pub(crate) name: &'static str,
    }

    #[derive(Debug, Clone)]
    pub struct SqliteColumn {
        pub(crate) name: String,
        pub(crate) type_info: SqliteTypeInfo,
    }

    #[derive(Debug, Clone)]
    pub struct SqliteRow {
        pub(crate) columns: Vec<SqliteColumn>,
        pub(crate) values: Vec<OwnedValue>,
    }

    impl SqliteRow {
        pub fn try_get<T, I>(&self, index: I) -> Result<T>
        where
            T: FromSql,
            I: super::ColumnIndex,
        {
            super::Row::try_get(self, index)
        }
    }

    pub use crate::query::Query;
}

pub trait TypeInfo {
    fn name(&self) -> &str;
}

impl TypeInfo for sqlite::SqliteTypeInfo {
    fn name(&self) -> &str {
        self.name
    }
}

pub trait Column {
    type Database;

    fn name(&self) -> &str;
    fn type_info(&self) -> &sqlite::SqliteTypeInfo;
}

impl Column for sqlite::SqliteColumn {
    type Database = Sqlite;

    fn name(&self) -> &str {
        &self.name
    }

    fn type_info(&self) -> &sqlite::SqliteTypeInfo {
        &self.type_info
    }
}

pub trait ColumnIndex {
    fn resolve(self, row: &sqlite::SqliteRow) -> Result<usize>;
}

impl ColumnIndex for usize {
    fn resolve(self, row: &sqlite::SqliteRow) -> Result<usize> {
        if self < row.values.len() {
            Ok(self)
        } else {
            Err(rusqlite::Error::InvalidColumnIndex(self).into())
        }
    }
}

impl ColumnIndex for i32 {
    fn resolve(self, row: &sqlite::SqliteRow) -> Result<usize> {
        usize::try_from(self)
            .map_err(|_| Error::Database(rusqlite::Error::InvalidColumnIndex(usize::MAX)))?
            .resolve(row)
    }
}

impl ColumnIndex for &str {
    fn resolve(self, row: &sqlite::SqliteRow) -> Result<usize> {
        row.columns
            .iter()
            .position(|column| column.name == self)
            .ok_or_else(|| rusqlite::Error::InvalidColumnName(self.to_string()).into())
    }
}

pub trait Row {
    type Database;

    fn columns(&self) -> &[sqlite::SqliteColumn];

    fn try_get<T, I>(&self, index: I) -> Result<T>
    where
        T: FromSql,
        I: ColumnIndex;
}

impl Row for sqlite::SqliteRow {
    type Database = Sqlite;

    fn columns(&self) -> &[sqlite::SqliteColumn] {
        &self.columns
    }

    fn try_get<T, I>(&self, index: I) -> Result<T>
    where
        T: FromSql,
        I: ColumnIndex,
    {
        let index = index.resolve(self)?;
        let value = self.values[index].as_ref();
        T::column_result(value).map_err(|error| {
            rusqlite::Error::FromSqlConversionFailure(index, value.data_type(), Box::new(error))
                .into()
        })
    }
}

pub trait FromRow: Sized {
    fn from_row(row: &sqlite::SqliteRow) -> Result<Self>;
}

macro_rules! impl_tuple_from_row {
    ($($index:tt => $name:ident),+ $(,)?) => {
        impl<$($name),+> FromRow for ($($name,)+)
        where
            $($name: FromSql,)+
        {
            fn from_row(row: &sqlite::SqliteRow) -> Result<Self> {
                Ok(($(Row::try_get(row, $index)?,)+))
            }
        }
    };
}

impl_tuple_from_row!(0 => A);
impl_tuple_from_row!(0 => A, 1 => B);
impl_tuple_from_row!(0 => A, 1 => B, 2 => C);
impl_tuple_from_row!(0 => A, 1 => B, 2 => C, 3 => D);
impl_tuple_from_row!(0 => A, 1 => B, 2 => C, 3 => D, 4 => E);
impl_tuple_from_row!(0 => A, 1 => B, 2 => C, 3 => D, 4 => E, 5 => F);
impl_tuple_from_row!(0 => A, 1 => B, 2 => C, 3 => D, 4 => E, 5 => F, 6 => G);
impl_tuple_from_row!(0 => A, 1 => B, 2 => C, 3 => D, 4 => E, 5 => F, 6 => G, 7 => H);
impl_tuple_from_row!(0 => A, 1 => B, 2 => C, 3 => D, 4 => E, 5 => F, 6 => G, 7 => H, 8 => I);
impl_tuple_from_row!(
    0 => A, 1 => B, 2 => C, 3 => D, 4 => E, 5 => F, 6 => G, 7 => H, 8 => I, 9 => J
);
impl_tuple_from_row!(
    0 => A, 1 => B, 2 => C, 3 => D, 4 => E, 5 => F, 6 => G, 7 => H, 8 => I, 9 => J, 10 => K
);
impl_tuple_from_row!(
    0 => A, 1 => B, 2 => C, 3 => D, 4 => E, 5 => F, 6 => G, 7 => H, 8 => I, 9 => J, 10 => K,
    11 => L
);

#[derive(Debug, Clone, Copy)]
pub struct SqliteQueryResult {
    rows_affected: u64,
}

impl SqliteQueryResult {
    pub fn rows_affected(&self) -> u64 {
        self.rows_affected
    }
}

fn bind_to_owned<T: ToSql>(value: T) -> Result<Value> {
    match value.to_sql()? {
        ToSqlOutput::Owned(value) => Ok(value),
        ToSqlOutput::Borrowed(ValueRef::Null) => Ok(Value::Null),
        ToSqlOutput::Borrowed(ValueRef::Integer(value)) => Ok(Value::Integer(value)),
        ToSqlOutput::Borrowed(ValueRef::Real(value)) => Ok(Value::Real(value)),
        ToSqlOutput::Borrowed(ValueRef::Text(value)) => {
            let value = std::str::from_utf8(value).map_err(|error| {
                Error::Configuration(format!("SQLite bind contains invalid UTF-8: {error}"))
            })?;
            Ok(Value::Text(value.to_string()))
        }
        ToSqlOutput::Borrowed(ValueRef::Blob(value)) => Ok(Value::Blob(value.to_vec())),
        _ => Err(Error::Configuration(
            "Unsupported SQLite bind value".to_string(),
        )),
    }
}

fn capture_rows(
    connection: &Connection,
    sql: &str,
    parameters: &[Value],
) -> Result<Vec<sqlite::SqliteRow>> {
    let mut statement = connection.prepare(sql)?;
    let column_names: Vec<String> = statement
        .column_names()
        .iter()
        .map(|name| (*name).to_string())
        .collect();
    let mut rows = statement.query(params_from_iter(parameters.iter()))?;
    let mut output = Vec::new();
    while let Some(row) = rows.next()? {
        let mut columns = Vec::with_capacity(column_names.len());
        let mut values = Vec::with_capacity(column_names.len());
        for (index, name) in column_names.iter().enumerate() {
            let value = OwnedValue::from_ref(row.get_ref(index)?);
            columns.push(sqlite::SqliteColumn {
                name: name.clone(),
                type_info: sqlite::SqliteTypeInfo {
                    name: value.type_name(),
                },
            });
            values.push(value);
        }
        output.push(sqlite::SqliteRow { columns, values });
    }
    Ok(output)
}

fn execute_query(
    connection: &Connection,
    sql: &str,
    parameters: &[Value],
) -> Result<SqliteQueryResult> {
    let rows_affected = if parameters.is_empty() {
        connection.execute_batch(sql)?;
        connection.changes()
    } else {
        connection.execute(sql, params_from_iter(parameters.iter()))? as u64
    };
    Ok(SqliteQueryResult { rows_affected })
}

async fn with_executor<'executor, DB, T, E, F>(executor: E, operation: F) -> Result<T>
where
    E: IntoExecutor<'executor, Database = DB>,
    F: FnOnce(&Connection) -> Result<T>,
{
    match executor.into_executor() {
        ExecutorRef::Pool(pool) => {
            let connection = pool.inner.lock().await;
            operation(&connection)
        }
        ExecutorRef::Connection(connection) => operation(connection),
    }
}

pub mod query {
    use super::*;

    #[derive(Debug, Clone)]
    pub struct Query<'query, DB = Sqlite, Arguments = sqlite::SqliteArguments<'query>> {
        sql: String,
        parameters: Vec<Value>,
        bind_error: Option<String>,
        _marker: PhantomData<(&'query (), DB, Arguments)>,
    }

    impl<'query, DB, Arguments> Query<'query, DB, Arguments> {
        pub fn bind<T: ToSql>(mut self, value: T) -> Self {
            match bind_to_owned(value) {
                Ok(value) => self.parameters.push(value),
                Err(error) => self.bind_error = Some(error.to_string()),
            }
            self
        }

        pub async fn execute<'executor, E>(self, executor: E) -> Result<SqliteQueryResult>
        where
            E: IntoExecutor<'executor, Database = DB>,
        {
            if let Some(error) = self.bind_error {
                return Err(Error::Configuration(error));
            }
            with_executor(executor, |connection| {
                execute_query(connection, &self.sql, &self.parameters)
            })
            .await
        }

        pub async fn fetch_all<'executor, E>(self, executor: E) -> Result<Vec<sqlite::SqliteRow>>
        where
            E: IntoExecutor<'executor, Database = DB>,
        {
            if let Some(error) = self.bind_error {
                return Err(Error::Configuration(error));
            }
            with_executor(executor, |connection| {
                capture_rows(connection, &self.sql, &self.parameters)
            })
            .await
        }

        pub async fn fetch_optional<'executor, E>(
            self,
            executor: E,
        ) -> Result<Option<sqlite::SqliteRow>>
        where
            E: IntoExecutor<'executor, Database = DB>,
        {
            Ok(self.fetch_all(executor).await?.into_iter().next())
        }

        pub async fn fetch_one<'executor, E>(self, executor: E) -> Result<sqlite::SqliteRow>
        where
            E: IntoExecutor<'executor, Database = DB>,
        {
            self.fetch_optional(executor)
                .await?
                .ok_or_else(|| rusqlite::Error::QueryReturnedNoRows.into())
        }
    }

    pub(crate) fn new(sql: &str) -> Query<'_, Sqlite, sqlite::SqliteArguments<'_>> {
        Query {
            sql: sql.to_string(),
            parameters: Vec::new(),
            bind_error: None,
            _marker: PhantomData,
        }
    }
}

#[derive(Debug, Clone)]
pub struct QueryAs<'query, DB, Output> {
    sql: String,
    parameters: Vec<Value>,
    bind_error: Option<String>,
    _marker: PhantomData<(&'query (), DB, Output)>,
}

impl<'query, DB, Output> QueryAs<'query, DB, Output> {
    pub fn bind<T: ToSql>(mut self, value: T) -> Self {
        match bind_to_owned(value) {
            Ok(value) => self.parameters.push(value),
            Err(error) => self.bind_error = Some(error.to_string()),
        }
        self
    }

    pub async fn fetch_all<'executor, E>(self, executor: E) -> Result<Vec<Output>>
    where
        E: IntoExecutor<'executor, Database = DB>,
        Output: FromRow,
    {
        if let Some(error) = self.bind_error {
            return Err(Error::Configuration(error));
        }
        let rows = with_executor(executor, |connection| {
            capture_rows(connection, &self.sql, &self.parameters)
        })
        .await?;
        rows.iter().map(Output::from_row).collect()
    }

    pub async fn fetch_optional<'executor, E>(self, executor: E) -> Result<Option<Output>>
    where
        E: IntoExecutor<'executor, Database = DB>,
        Output: FromRow,
    {
        Ok(self.fetch_all(executor).await?.into_iter().next())
    }

    pub async fn fetch_one<'executor, E>(self, executor: E) -> Result<Output>
    where
        E: IntoExecutor<'executor, Database = DB>,
        Output: FromRow,
    {
        self.fetch_optional(executor)
            .await?
            .ok_or_else(|| rusqlite::Error::QueryReturnedNoRows.into())
    }
}

#[derive(Debug, Clone)]
pub struct QueryScalar<'query, DB, Output> {
    sql: String,
    parameters: Vec<Value>,
    bind_error: Option<String>,
    _marker: PhantomData<(&'query (), DB, Output)>,
}

impl<'query, DB, Output> QueryScalar<'query, DB, Output> {
    pub fn bind<T: ToSql>(mut self, value: T) -> Self {
        match bind_to_owned(value) {
            Ok(value) => self.parameters.push(value),
            Err(error) => self.bind_error = Some(error.to_string()),
        }
        self
    }

    pub async fn fetch_all<'executor, E>(self, executor: E) -> Result<Vec<Output>>
    where
        E: IntoExecutor<'executor, Database = DB>,
        Output: FromSql,
    {
        if let Some(error) = self.bind_error {
            return Err(Error::Configuration(error));
        }
        let rows = with_executor(executor, |connection| {
            capture_rows(connection, &self.sql, &self.parameters)
        })
        .await?;
        rows.iter().map(|row| Row::try_get(row, 0usize)).collect()
    }

    pub async fn fetch_optional<'executor, E>(self, executor: E) -> Result<Option<Output>>
    where
        E: IntoExecutor<'executor, Database = DB>,
        Output: FromSql,
    {
        Ok(self.fetch_all(executor).await?.into_iter().next())
    }

    pub async fn fetch_one<'executor, E>(self, executor: E) -> Result<Output>
    where
        E: IntoExecutor<'executor, Database = DB>,
        Output: FromSql,
    {
        self.fetch_optional(executor)
            .await?
            .ok_or_else(|| rusqlite::Error::QueryReturnedNoRows.into())
    }
}

pub fn query(sql: &str) -> query::Query<'_, Sqlite, sqlite::SqliteArguments<'_>> {
    query::new(sql)
}

pub fn query_as<'query, DB, Output>(sql: &'query str) -> QueryAs<'query, DB, Output> {
    QueryAs {
        sql: sql.to_string(),
        parameters: Vec::new(),
        bind_error: None,
        _marker: PhantomData,
    }
}

pub fn query_scalar<'query, DB, Output>(sql: &'query str) -> QueryScalar<'query, DB, Output> {
    QueryScalar {
        sql: sql.to_string(),
        parameters: Vec::new(),
        bind_error: None,
        _marker: PhantomData,
    }
}

#[cfg(target_arch = "wasm32")]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum WebStorageBackend {
    Opfs,
    RelaxedIdb,
}

#[cfg(target_arch = "wasm32")]
static WEB_STORAGE_BACKEND: std::sync::OnceLock<WebStorageBackend> = std::sync::OnceLock::new();

#[cfg(target_arch = "wasm32")]
fn web_uses_relaxed_idb() -> bool {
    WEB_STORAGE_BACKEND.get() == Some(&WebStorageBackend::RelaxedIdb)
}

#[cfg(target_arch = "wasm32")]
pub async fn install_web_vfs() -> Result<()> {
    use sqlite_wasm_rs::WasmOsCallback;
    use sqlite_wasm_vfs::relaxed_idb::{install as install_idb, RelaxedIdbCfgBuilder};
    use sqlite_wasm_vfs::sahpool::{install as install_opfs, OpfsSAHPoolCfgBuilder};

    if WEB_STORAGE_BACKEND.get().is_some() {
        return Ok(());
    }

    let opfs_options = OpfsSAHPoolCfgBuilder::new()
        .directory(".openlogtool")
        .initial_capacity(8)
        .build();
    let backend = match install_opfs::<WasmOsCallback>(&opfs_options, true).await {
        Ok(_) => WebStorageBackend::Opfs,
        Err(opfs_error) => {
            let idb_options = RelaxedIdbCfgBuilder::new()
                .vfs_name("openlogtool-idb")
                .build();
            install_idb::<WasmOsCallback>(&idb_options, true)
                .await
                .map_err(|idb_error| {
                    Error::Configuration(format!(
                        "WEB_SQLITE_PERSISTENCE_UNAVAILABLE: OPFS: {opfs_error}; IndexedDB: {idb_error}"
                    ))
                })?;
            WebStorageBackend::RelaxedIdb
        }
    };
    let _ = WEB_STORAGE_BACKEND.set(backend);
    Ok(())
}

#[cfg(not(target_arch = "wasm32"))]
pub async fn install_web_vfs() -> Result<()> {
    Ok(())
}
