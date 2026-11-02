//! Minimal C ABI so a non-FRB host (the fanqie app's Dart FFI) can boot the
//! fqapi core loopback HTTP server.
//!
//! `fanqie_init` spawns a thread that owns a multi-thread tokio runtime and
//! runs `fqapi_core::api::init` on it; the runtime is kept alive for the
//! process lifetime so the spawned server tasks keep serving. `fanqie_status`
//! reports 1 once the core answers (probe is a plain loopback HTTP GET done by
//! the caller — here we just report that init finished without error).

use std::ffi::{c_char, c_int, CStr};
use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{OnceLock, Mutex};
use tokio::runtime::Runtime;

static RT: OnceLock<Runtime> = OnceLock::new();
static STATE: AtomicU64 = AtomicU64::new(0); // 0=idle 1=starting 2=running 3=failed
static LOG_DIR: OnceLock<PathBuf> = OnceLock::new();
static LOG_LOCK: Mutex<()> = Mutex::new(());

fn log_line(kind: &str, text: &str) {
    let Some(dir) = LOG_DIR.get() else { return };
    let _guard = LOG_LOCK.lock();
    use std::io::Write;
    if let Ok(mut file) = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(dir.join("fanqie_engine.log"))
    {
        let _ = writeln!(file, "[{kind}] {text}");
    }
}

unsafe fn read_str(ptr: *const c_char) -> String {
    if ptr.is_null() {
        return String::new();
    }
    CStr::from_ptr(ptr).to_string_lossy().into_owned()
}

#[no_mangle]
pub extern "C" fn fanqie_init(
    config_path: *const c_char,
    pool_path: *const c_char,
    filter_path: *const c_char,
    runtime_dir: *const c_char,
    port: u16,
) -> c_int {
    if STATE.load(Ordering::SeqCst) != 0 {
        return 0; // already started; idempotent
    }
    let config_path = unsafe { read_str(config_path) };
    let pool_path = unsafe { read_str(pool_path) };
    let filter_path = unsafe { read_str(filter_path) };
    let runtime_dir = unsafe { read_str(runtime_dir) };
    let _ = LOG_DIR.set(PathBuf::from(runtime_dir.clone()));
    let default_hook = std::panic::take_hook();
    std::panic::set_hook(Box::new(move |info| {
        log_line("panic", &format!("{info}"));
        default_hook(info);
    }));
    STATE.store(1, Ordering::SeqCst);
    let runtime = match RT.get_or_init(|| {
        tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .expect("fanqie_shim: tokio runtime")
    }) {
        runtime => runtime,
    };
    std::thread::spawn(move || {
        log_line("info", &format!("init begin: port={port} runtime={runtime_dir}"));
        let result = runtime.block_on(fqapi_core::api::init(
            config_path,
            pool_path,
            filter_path,
            runtime_dir,
            port,
            false,
            String::new(),
        ));
        match result {
            Ok(status) => {
                log_line("info", &format!("init ok: {status}"));
                eprintln!("fanqie_shim: init {status}");
                STATE.store(2, Ordering::SeqCst);
            }
            Err(error) => {
                log_line("error", &format!("init failed: {error}"));
                eprintln!("fanqie_shim: init failed: {error}");
                STATE.store(3, Ordering::SeqCst);
            }
        }
    });
    0
}

/// 1 = running, 0 = starting, -1 = failed.
#[no_mangle]
pub extern "C" fn fanqie_status() -> c_int {
    match STATE.load(Ordering::SeqCst) {
        2 => 1,
        3 => -1,
        _ => 0,
    }
}

#[no_mangle]
pub extern "C" fn fanqie_version() -> *const c_char {
    b"fanqie_shim 0.1.0\0".as_ptr() as *const c_char
}
