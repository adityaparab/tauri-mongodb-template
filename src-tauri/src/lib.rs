use mongodb::{
    bson::{doc, Document},
    options::FindOptions,
    sync::Client,
};
use serde::Serialize;
use std::{
    fs,
    net::{SocketAddr, TcpStream},
    path::PathBuf,
    process::{Child, Command, Stdio},
    sync::{Arc, Mutex},
    thread,
    time::{Duration, Instant},
};
use tauri::{AppHandle, Manager, State};

const CONFIG_FILE_NAME: &str = "inventory.ini";
const DATABASE_NAME: &str = "inventory";
const MONGO_HOST: &str = "127.0.0.1";
const MONGO_PORT: u16 = 27017;
const MONGO_URI: &str = "mongodb://127.0.0.1:27017/inventory";
const MONGO_DRIVER_URI: &str =
    "mongodb://127.0.0.1:27017/inventory?serverSelectionTimeoutMS=3000";
const DOCUMENT_LIMIT: i64 = 200;

#[derive(Clone, Default)]
struct MongoState {
    child: Arc<Mutex<Option<Child>>>,
}

impl Drop for MongoState {
    fn drop(&mut self) {
        if Arc::strong_count(&self.child) == 1 {
            stop_owned_mongodb(self);
        }
    }
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct MongoStatus {
    configured: bool,
    db_path: Option<String>,
    config_path: String,
    running: bool,
    connection_uri: String,
    database: String,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct DocumentsResponse {
    documents: Vec<serde_json::Value>,
    limit: i64,
}

fn format_error(error: impl std::fmt::Display) -> String {
    error.to_string()
}

fn config_file_path() -> Result<PathBuf, String> {
    let exe_path = std::env::current_exe().map_err(format_error)?;
    let install_dir = exe_path
        .parent()
        .ok_or_else(|| "Could not find the application installation directory".to_string())?;

    Ok(install_dir.join(CONFIG_FILE_NAME))
}

fn read_db_path_from_config() -> Result<Option<PathBuf>, String> {
    let config_path = config_file_path()?;

    if !config_path.exists() {
        return Ok(None);
    }

    let content = fs::read_to_string(&config_path).map_err(format_error)?;
    let mut in_mongodb_section = false;

    for line in content.lines() {
        let line = line.trim();

        if line.is_empty() || line.starts_with(';') || line.starts_with('#') {
            continue;
        }

        if line.starts_with('[') && line.ends_with(']') {
            in_mongodb_section = line[1..line.len() - 1].eq_ignore_ascii_case("mongodb");
            continue;
        }

        if in_mongodb_section {
            if let Some((key, value)) = line.split_once('=') {
                if key.trim().eq_ignore_ascii_case("dbPath") {
                    let value = value.trim();

                    if !value.is_empty() {
                        return Ok(Some(PathBuf::from(value)));
                    }
                }
            }
        }
    }

    Err(format!(
        "MongoDB database path is missing from {}",
        config_path.display()
    ))
}

fn write_db_path_config(db_path: &PathBuf) -> Result<(), String> {
    let config_path = config_file_path()?;
    let content = format!("[mongodb]\ndbPath={}\n", db_path.display());

    fs::write(config_path, content).map_err(format_error)
}

fn mongodb_status() -> Result<MongoStatus, String> {
    let config_path = config_file_path()?;
    let db_path = read_db_path_from_config()?;

    Ok(MongoStatus {
        configured: db_path.is_some(),
        db_path: db_path.map(|path| path.display().to_string()),
        config_path: config_path.display().to_string(),
        running: is_mongodb_port_open(),
        connection_uri: MONGO_URI.to_string(),
        database: DATABASE_NAME.to_string(),
    })
}

fn mongod_binary_path(app: &AppHandle) -> Result<PathBuf, String> {
    #[cfg(debug_assertions)]
    {
        let local_binary = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("binaries")
            .join("mongod.exe");

        if local_binary.exists() {
            return Ok(local_binary);
        }
    }

    let resource_binary = app
        .path()
        .resource_dir()
        .map_err(format_error)?
        .join("binaries")
        .join("mongod.exe");

    if resource_binary.exists() {
        Ok(resource_binary)
    } else {
        Err(format!(
            "MongoDB server binary was not found at {}",
            resource_binary.display()
        ))
    }
}

fn is_mongodb_port_open() -> bool {
    let address = SocketAddr::from(([127, 0, 0, 1], MONGO_PORT));

    TcpStream::connect_timeout(&address, Duration::from_millis(250)).is_ok()
}

fn wait_for_mongodb() -> Result<(), String> {
    let started_at = Instant::now();

    while started_at.elapsed() < Duration::from_secs(8) {
        if is_mongodb_port_open() {
            return Ok(());
        }

        thread::sleep(Duration::from_millis(150));
    }

    Err(format!(
        "MongoDB did not start on {MONGO_HOST}:{MONGO_PORT} before the timeout"
    ))
}

fn stop_owned_mongodb(state: &MongoState) {
    let Ok(mut child_guard) = state.child.lock() else {
        return;
    };

    if let Some(mut child) = child_guard.take() {
        let _ = child.kill();
        let _ = child.wait();
    }
}

fn ensure_mongodb_started(app: &AppHandle, state: &MongoState) -> Result<(), String> {
    if is_mongodb_port_open() {
        return Ok(());
    }

    {
        let mut child_guard = state.child.lock().map_err(format_error)?;

        if let Some(child) = child_guard.as_mut() {
            match child.try_wait().map_err(format_error)? {
                Some(status) => {
                    *child_guard = None;
                    return Err(format!("MongoDB exited before it was ready: {status}"));
                }
                None => return wait_for_mongodb(),
            }
        }
    }

    let db_path = read_db_path_from_config()?
        .ok_or_else(|| "MongoDB database folder has not been configured".to_string())?;

    fs::create_dir_all(&db_path).map_err(format_error)?;

    let log_path = db_path.join("mongod.log");
    let mut command = Command::new(mongod_binary_path(app)?);
    command
        .arg("--dbpath")
        .arg(&db_path)
        .arg("--bind_ip")
        .arg(MONGO_HOST)
        .arg("--port")
        .arg(MONGO_PORT.to_string())
        .arg("--logpath")
        .arg(log_path)
        .arg("--logappend")
        .stdout(Stdio::null())
        .stderr(Stdio::null());

    #[cfg(target_os = "windows")]
    {
        use std::os::windows::process::CommandExt;
        command.creation_flags(0x08000000);
    }

    let child = command.spawn().map_err(format_error)?;

    {
        let mut child_guard = state.child.lock().map_err(format_error)?;
        *child_guard = Some(child);
    }

    wait_for_mongodb()
}

fn inventory_database() -> Result<mongodb::sync::Database, String> {
    let client = Client::with_uri_str(MONGO_DRIVER_URI).map_err(format_error)?;

    Ok(client.database(DATABASE_NAME))
}

#[tauri::command]
fn get_mongodb_status() -> Result<MongoStatus, String> {
    mongodb_status()
}

#[tauri::command]
fn set_mongodb_path(
    path: String,
    app: AppHandle,
    state: State<'_, MongoState>,
) -> Result<MongoStatus, String> {
    let trimmed_path = path.trim();

    if trimmed_path.is_empty() {
        return Err("Choose a MongoDB database folder".to_string());
    }

    let db_path = PathBuf::from(trimmed_path);

    if !db_path.is_absolute() {
        return Err("MongoDB database folder must be an absolute path".to_string());
    }

    fs::create_dir_all(&db_path).map_err(format_error)?;
    write_db_path_config(&db_path)?;
    stop_owned_mongodb(&state);
    ensure_mongodb_started(&app, &state)?;

    mongodb_status()
}

#[tauri::command]
fn list_collections(app: AppHandle, state: State<'_, MongoState>) -> Result<Vec<String>, String> {
    ensure_mongodb_started(&app, &state)?;

    let database = inventory_database()?;
    let mut names = database.list_collection_names(None).map_err(format_error)?;
    names.sort_by_key(|name| name.to_lowercase());

    Ok(names)
}

#[tauri::command]
fn list_documents(
    collection: String,
    app: AppHandle,
    state: State<'_, MongoState>,
) -> Result<DocumentsResponse, String> {
    ensure_mongodb_started(&app, &state)?;

    let collection_name = collection.trim();

    if collection_name.is_empty() {
        return Err("Choose a collection".to_string());
    }

    let database = inventory_database()?;
    let find_options = FindOptions::builder().limit(DOCUMENT_LIMIT).build();
    let cursor = database
        .collection::<Document>(collection_name)
        .find(doc! {}, find_options)
        .map_err(format_error)?;
    let mut documents = Vec::new();

    for result in cursor {
        let document = result.map_err(format_error)?;
        documents.push(serde_json::to_value(document).map_err(format_error)?);
    }

    Ok(DocumentsResponse {
        documents,
        limit: DOCUMENT_LIMIT,
    })
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .manage(MongoState::default())
        .setup(|app| {
            let app_handle = app.handle().clone();
            let mongo_state = app.state::<MongoState>().inner().clone();

            thread::spawn(move || {
                if let Err(error) = ensure_mongodb_started(&app_handle, &mongo_state) {
                    eprintln!("Could not start MongoDB: {error}");
                }
            });

            Ok(())
        })
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![
            get_mongodb_status,
            set_mongodb_path,
            list_collections,
            list_documents
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
