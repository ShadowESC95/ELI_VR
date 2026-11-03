//! The key a client must give before it sees the screen or moves the pointer, so only ELI VR run
//! by the same person on this computer can: another account on it can reach a loopback port, but
//! not this file. The helper makes a new key each time it starts; ELI VR reads it from the same
//! place (scripts/desktop/desktop_bridge_client.gd, `key_path`).

use std::{
    collections::hash_map::RandomState,
    env, fs,
    hash::{BuildHasher, Hasher},
    io::Write,
    path::PathBuf,
};

/// Where the key is kept: the session's own runtime folder on Linux, else the account's own
/// application folder.
pub fn path() -> Option<PathBuf> {
    let home = || env::var_os("HOME").map(PathBuf::from);
    if cfg!(windows) {
        env::var_os("LOCALAPPDATA").map(|d| PathBuf::from(d).join("ELI VR").join("desktop-key"))
    } else if cfg!(target_os = "macos") {
        home().map(|h| h.join("Library/Application Support/ELI VR/desktop-key"))
    } else if let Some(run) = env::var_os("XDG_RUNTIME_DIR").filter(|d| !d.is_empty()) {
        Some(PathBuf::from(run).join("eli-vr-desktop-key"))
    } else {
        home().map(|h| h.join(".local/state/eli-vr-standalone/desktop-key"))
    }
}

/// A new key, from the randomness the standard library seeds its hash maps with.
pub fn fresh() -> String {
    (0..2).map(|_| format!("{:016x}", RandomState::new().build_hasher().finish())).collect()
}

/// Make a new key and keep it where ELI VR looks, readable by this account alone.
pub fn issue() -> std::io::Result<String> {
    let key = fresh();
    let path = path().ok_or_else(|| std::io::Error::other("no folder for the key: HOME/LOCALAPPDATA is not set"))?;
    if let Some(folder) = path.parent() {
        fs::create_dir_all(folder)?;
    }
    let _ = fs::remove_file(&path);
    let mut options = fs::OpenOptions::new();
    options.write(true).create_new(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.mode(0o600);
    }
    options.open(&path)?.write_all(key.as_bytes())?;
    Ok(key)
}

/// Whether a client's first line is a hello with this key.
pub fn admits(line: &str, key: &str) -> bool {
    serde_json::from_str::<serde_json::Value>(line)
        .ok()
        .filter(|hello| hello.get("kind").and_then(|k| k.as_str()) == Some("hello"))
        .and_then(|hello| hello.get("key").and_then(|k| k.as_str()).map(|given| given == key))
        .unwrap_or(false)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn keys_are_long_and_different() {
        let (a, b) = (fresh(), fresh());
        assert_eq!(a.len(), 32);
        assert_ne!(a, b);
    }

    #[test]
    fn only_a_hello_with_the_key_is_admitted() {
        assert!(admits(r#"{"kind": "hello", "key": "abc"}"#, "abc"));
        for line in [r#"{"kind": "hello", "key": "abd"}"#, r#"{"kind": "hello"}"#, r#"{"kind": "move", "key": "abc"}"#,
                     "GET / HTTP/1.1", ""] {
            assert!(!admits(line, "abc"), "{line}");
        }
    }
}
