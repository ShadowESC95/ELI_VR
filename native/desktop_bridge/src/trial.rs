//! ELI VR's free trial: seven days from its first use, the trial every ELI product gives (ELI v3,
//! ELI Legal, ELI Creation Station), kept exactly as eli-sdk's `LocalTrial` keeps it
//! (`eli_sdk/trial.py`), so the record one product's code writes is the record another's reads.
//!
//! What does not restart it, as there:
//!
//! - **Deleting its record.** It is mirrored to three folders of this account (and, on Windows,
//!   the registry); a missing copy is written again from the others at the next launch.
//! - **Changing environment variables.** The folders are found from the account itself, not from
//!   `$HOME` or `XDG_*` (on Windows, `%APPDATA%` and `%LOCALAPPDATA%`, which eli-sdk reads from
//!   Windows' known folders: the same folders unless someone has changed those variables).
//! - **Editing it.** Each copy is sealed with a code tied to this machine (HMAC-SHA-256 under a
//!   secret made from eli-sdk's seal and the machine's fingerprint); an altered copy ends the
//!   trial, and so does a copy taken from another machine.
//! - **Setting the clock back.** The latest time ELI VR ran is kept; a clock more than six hours
//!   behind it stops the trial until the clock is right again.
//! - **Deleting every copy.** ELI VR's own data from earlier use (its settings folder) means the
//!   trial was had, and no new one starts.
//!
//! The machine's fingerprint is eli-sdk's (`eli_sdk/machine.py`): a SHA-256 of
//! `eliv3-machine-v2|<system>|<machine>|<the system's own install id>|`, with Python's names for
//! the system (`Linux`, `Darwin`, `Windows`) and the processor (`uname -m`; Windows'
//! `PROCESSOR_ARCHITECTURE`). `tests/trial_vectors.json` holds a fingerprint and a sealed record
//! that eli-sdk itself produced; the tests below read them as eli-sdk does.

use std::{
    env, fs,
    io::Write,
    path::{Path, PathBuf},
    process::Command,
    time::{SystemTime, UNIX_EPOCH},
};

use chrono::{DateTime, Duration, SecondsFormat, Utc};
use serde_json::{Map, Value, json};
use sha2::{Digest, Sha256};

pub const TRIAL_DAYS: i64 = 7;
const SEAL: &[u8] = b"eli-sdk/trial/v1/4d2b8f0e6a1c93e7";
const VERSION: i64 = 1;
const CLOCK_SLACK_HOURS: i64 = 6;
const FINGERPRINT_PREFIX: &str = "eliv3-machine-v2";
const REGISTRY_KEY: &str = r"HKCU\Software\ELI\Trials";

// ── hashing ───────────────────────────────────────────────────────────────────
fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

fn sha256(data: &[u8]) -> [u8; 32] {
    Sha256::digest(data).into()
}

/// HMAC-SHA-256 (RFC 2104), as Python's `hmac.new(key, body, hashlib.sha256)`.
fn hmac_sha256(key: &[u8], message: &[u8]) -> [u8; 32] {
    let mut block = [0u8; 64];
    if key.len() > 64 {
        block[..32].copy_from_slice(&sha256(key));
    } else {
        block[..key.len()].copy_from_slice(key);
    }
    let mut inner = Sha256::new();
    inner.update(block.map(|b| b ^ 0x36));
    inner.update(message);
    let mut outer = Sha256::new();
    outer.update(block.map(|b| b ^ 0x5c));
    outer.update(inner.finalize());
    outer.finalize().into()
}

/// A JSON string as Python's `json.dumps` writes it (non-ASCII as `\uXXXX`).
fn py_string(text: &str) -> String {
    let mut out = String::with_capacity(text.len() + 2);
    out.push('"');
    for c in text.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            '\u{08}' => out.push_str("\\b"),
            '\u{0c}' => out.push_str("\\f"),
            c if (c as u32) < 0x20 || (c as u32) > 0x7e => {
                let mut units = [0u16; 2];
                for unit in c.encode_utf16(&mut units) {
                    out.push_str(&format!("\\u{unit:04x}"));
                }
            }
            c => out.push(c),
        }
    }
    out.push('"');
    out
}

fn py_value(value: &Value) -> String {
    match value {
        Value::String(s) => py_string(s),
        Value::Object(map) => py_object(map, ",", ":"),
        Value::Array(items) => format!("[{}]", items.iter().map(py_value).collect::<Vec<_>>().join(",")),
        other => other.to_string(),
    }
}

/// An object with its keys sorted, as `json.dumps(..., sort_keys=True, separators=(item, key))`.
fn py_object(map: &Map<String, Value>, item: &str, key: &str) -> String {
    let mut keys: Vec<&String> = map.keys().collect();
    keys.sort();
    let body: Vec<String> = keys.iter().map(|k| format!("{}{key}{}", py_string(k), py_value(&map[*k]))).collect();
    format!("{{{}}}", body.join(item))
}

// ── this account and this machine ─────────────────────────────────────────────
fn run(program: &str, args: &[&str]) -> String {
    Command::new(program)
        .args(args)
        .output()
        .ok()
        .filter(|out| out.status.success())
        .map(|out| String::from_utf8_lossy(&out.stdout).into_owned())
        .unwrap_or_default()
}

fn first_line(path: &Path) -> String {
    fs::read_to_string(path).map(|t| t.trim().to_string()).unwrap_or_default()
}

/// This account's home folder as the system records it, not as `$HOME` says.
pub fn account_home() -> PathBuf {
    let from_env = || {
        ["HOME", "USERPROFILE"]
            .iter()
            .find_map(|name| env::var_os(name).filter(|v| !v.is_empty()))
            .map_or_else(|| PathBuf::from("."), PathBuf::from)
    };
    if cfg!(windows) {
        return env::var_os("USERPROFILE").filter(|v| !v.is_empty()).map_or_else(from_env, PathBuf::from);
    }
    let uid = run("id", &["-u"]).trim().to_string();
    if cfg!(target_os = "macos") {
        let name = run("id", &["-un"]).trim().to_string();
        let out = run("dscl", &[".", "-read", &format!("/Users/{name}"), "NFSHomeDirectory"]);
        if let Some(home) = out.split_once(':').map(|(_, v)| v.trim()).filter(|v| !v.is_empty()) {
            return PathBuf::from(home);
        }
        return from_env();
    }
    // the password database: /etc/passwd, then NSS (LDAP and the like) through getent
    let entry = fs::read_to_string("/etc/passwd")
        .ok()
        .and_then(|t| t.lines().find(|l| l.split(':').nth(2) == Some(uid.as_str())).map(str::to_string))
        .or_else(|| Some(run("getent", &["passwd", &uid])).filter(|l| !l.trim().is_empty()));
    entry
        .and_then(|l| l.trim().split(':').nth(5).map(str::to_string))
        .filter(|h| !h.is_empty())
        .map_or_else(from_env, PathBuf::from)
}

fn python_system() -> &'static str {
    match env::consts::OS {
        "linux" => "Linux",
        "macos" => "Darwin",
        "windows" => "Windows",
        "freebsd" => "FreeBSD",
        other => other,
    }
}

fn python_machine() -> String {
    if cfg!(windows) {
        for name in ["PROCESSOR_ARCHITEW6432", "PROCESSOR_ARCHITECTURE"] {
            if let Some(value) = env::var(name).ok().filter(|v| !v.is_empty()) {
                return value;
            }
        }
        return match env::consts::ARCH {
            "x86_64" => "AMD64",
            "aarch64" => "ARM64",
            other => other,
        }
        .to_string();
    }
    let uname = run("uname", &["-m"]).trim().to_string();
    if uname.is_empty() { env::consts::ARCH.to_string() } else { uname }
}

fn random_hex(len: usize) -> String {
    let nanos = SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_nanos()).unwrap_or(0);
    let local = 0u8;
    let seed = format!("{nanos}|{}|{:p}|{:?}", std::process::id(), &local, std::thread::current().id());
    let mut out = String::new();
    let mut round = 0u32;
    while out.len() < len {
        out.push_str(&hex(&sha256(format!("{seed}|{round}").as_bytes())));
        round += 1;
    }
    out.truncate(len);
    out
}

/// The identity the operating system gives this installation of itself.
pub fn install_id() -> String {
    let value = if cfg!(windows) {
        run("reg", &["query", r"HKLM\SOFTWARE\Microsoft\Cryptography", "/v", "MachineGuid", "/reg:64"])
            .lines()
            .find(|l| l.contains("MachineGuid"))
            .and_then(|l| l.split_whitespace().last().map(str::to_string))
            .unwrap_or_default()
    } else if cfg!(target_os = "macos") {
        run("/usr/sbin/ioreg", &["-rd1", "-c", "IOPlatformExpertDevice"])
            .lines()
            .find(|l| l.contains("IOPlatformUUID") && l.contains('"'))
            .and_then(|l| l.rsplit('"').nth(1).map(|v| v.trim().to_string()))
            .unwrap_or_default()
    } else {
        [Path::new("/etc/machine-id"), Path::new("/var/lib/dbus/machine-id")]
            .iter()
            .map(|p| first_line(p))
            .find(|v| !v.is_empty())
            .unwrap_or_default()
    };
    if !value.is_empty() {
        return value;
    }
    // Last resort, as eli-sdk: an id made once and kept in this account's own folder.
    let path = account_home().join(".eli-keys-machine-id");
    let kept = first_line(&path);
    if !kept.is_empty() {
        return kept;
    }
    let made = random_hex(32);
    match write_private(&path, &format!("{made}\n")) {
        Ok(()) => made,
        Err(_) => format!("ephemeral-{}", &made[..12]),
    }
}

pub fn fingerprint_of(system: &str, machine: &str, install: &str) -> String {
    let text = [FINGERPRINT_PREFIX, system, machine, install, ""].join("|");
    hex(&sha256(text.as_bytes()))
}

/// This machine, as eli-sdk's `machine.fingerprint()` gives it.
pub fn fingerprint() -> String {
    fingerprint_of(python_system(), &python_machine(), &install_id())
}

fn write_private(path: &Path, text: &str) -> std::io::Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    let tmp = path.with_extension(format!("t-{}", random_hex(8)));
    {
        let mut options = fs::OpenOptions::new();
        options.write(true).create_new(true);
        #[cfg(unix)]
        std::os::unix::fs::OpenOptionsExt::mode(&mut options, 0o600);
        options.open(&tmp)?.write_all(text.as_bytes())?;
    }
    fs::rename(&tmp, path).inspect_err(|_| {
        let _ = fs::remove_file(&tmp);
    })
}

/// The folders a trial's record is mirrored to, found from the account itself.
pub fn default_locations() -> Vec<PathBuf> {
    let home = account_home();
    if cfg!(windows) {
        let known = |name: &str, fallback: &[&str]| {
            env::var_os(name)
                .filter(|v| !v.is_empty())
                .map_or_else(|| fallback.iter().fold(home.clone(), |p, part| p.join(part)), PathBuf::from)
        };
        return vec![
            known("APPDATA", &["AppData", "Roaming"]).join("ELI Keys"),
            known("LOCALAPPDATA", &["AppData", "Local"]).join("ELI Keys").join("State"),
            home.join(".eli-keys"),
        ];
    }
    if cfg!(target_os = "macos") {
        let lib = home.join("Library");
        return vec![
            lib.join("Application Support").join("ELI Keys"),
            lib.join("Preferences").join("ELI Keys"),
            home.join(".eli-keys"),
        ];
    }
    vec![
        home.join(".config").join("eli-keys"),
        home.join(".local").join("share").join("eli-keys"),
        home.join(".local").join("state").join("eli-keys"),
    ]
}

/// Where the Godot app keeps ELI VR's own data (`user://`), found from the account itself.
pub fn app_data_folders() -> Vec<PathBuf> {
    let home = account_home();
    let godot = if cfg!(windows) {
        env::var_os("APPDATA").map_or_else(|| home.join("AppData").join("Roaming"), PathBuf::from).join("Godot")
    } else if cfg!(target_os = "macos") {
        home.join("Library").join("Application Support").join("Godot")
    } else {
        home.join(".local").join("share").join("godot")
    };
    vec![godot.join("app_userdata").join("ELI VR").join("eli_vr")]
}

// ── the trial ────────────────────────────────────────────────────────────────
fn iso(moment: DateTime<Utc>) -> String {
    // Python: datetime.isoformat() of a UTC time without microseconds
    moment.to_rfc3339_opts(SecondsFormat::Secs, false)
}

fn when(value: Option<&Value>) -> Option<DateTime<Utc>> {
    let text = value?.as_str()?;
    DateTime::parse_from_rfc3339(&text.replace('Z', "+00:00")).ok().map(|d| d.with_timezone(&Utc))
}

fn text(record: &Map<String, Value>, key: &str) -> String {
    record.get(key).and_then(Value::as_str).unwrap_or_default().to_string()
}

#[derive(Debug, Clone, PartialEq)]
pub struct TrialStatus {
    pub product: String,
    pub state: String, // available | active | ended
    pub days: i64,
    pub started_at: String,
    pub ends_at: String,
    pub reference: String,
    pub why: String,
    pub final_: bool,
}

impl TrialStatus {
    pub fn active(&self) -> bool {
        self.state == "active"
    }

    pub fn days_left(&self, now: DateTime<Utc>) -> i64 {
        match (self.active(), when(Some(&Value::String(self.ends_at.clone())))) {
            (true, Some(ends)) => {
                let seconds = (ends - now).num_seconds();
                (seconds + 86_399).div_euclid(86_400).max(0)
            }
            _ => 0,
        }
    }

    pub fn describe(&self, label: &str, now: DateTime<Utc>) -> String {
        match self.state.as_str() {
            "active" => {
                let n = self.days_left(now);
                format!("{label} trial: {n} day{} left", if n == 1 { "" } else { "s" })
            }
            "available" => format!("a {}-day {label} trial starts the first time it is used", self.days),
            _ if !self.why.is_empty() => self.why.clone(),
            _ => format!("the {label} trial has ended"),
        }
    }

    pub fn to_json(&self, label: &str, now: DateTime<Utc>) -> Value {
        json!({
            "state": self.state,
            "days": self.days,
            "days_left": self.days_left(now),
            "started_at": self.started_at,
            "ends_at": self.ends_at,
            "reference": self.reference,
            "why": self.why,
            "describe": self.describe(label, now),
        })
    }
}

pub struct LocalTrial {
    pub product: String,
    pub label: String,
    pub days: i64,
    pub machine: String,
    pub locations: Vec<PathBuf>,
    pub used_before: Box<dyn Fn() -> bool>,
    pub registry: bool,
}

impl LocalTrial {
    /// The trial on this machine, in the folders every ELI product mirrors trials to.
    pub fn new(product: &str, label: &str, used_before: Box<dyn Fn() -> bool>) -> Self {
        Self {
            product: product.to_lowercase(),
            label: label.to_string(),
            days: TRIAL_DAYS,
            machine: fingerprint(),
            locations: default_locations(),
            used_before,
            registry: cfg!(windows),
        }
    }

    pub fn paths(&self) -> Vec<PathBuf> {
        self.locations.iter().map(|f| f.join(format!(".{}-trial", self.product))).collect()
    }

    pub fn seal(&self, record: &Map<String, Value>) -> String {
        let mut secret = SEAL.to_vec();
        secret.extend_from_slice(self.machine.as_bytes());
        let body = py_object(record, ",", ":");
        hex(&hmac_sha256(&sha256(&secret), body.as_bytes()))
    }

    /// A record as eli-sdk writes it: `json.dumps({**record, "seal": ...}, sort_keys=True) + "\n"`.
    pub fn sealed(&self, record: &Map<String, Value>) -> String {
        let mut with_seal = record.clone();
        with_seal.insert("seal".into(), Value::String(self.seal(record)));
        format!("{}\n", py_object(&with_seal, ", ", ": "))
    }

    /// The record, if its seal holds for this machine and product.
    pub fn open(&self, text: &str) -> Option<Map<String, Value>> {
        let Value::Object(mut raw) = serde_json::from_str::<Value>(text).ok()? else {
            return None;
        };
        let seal = raw.remove("seal").and_then(|s| s.as_str().map(str::to_string)).unwrap_or_default();
        if seal != self.seal(&raw) {
            return None;
        }
        let same = |key: &str, want: &str| raw.get(key).and_then(Value::as_str) == Some(want);
        (same("product", &self.product) && same("machine", &self.machine)).then_some(raw)
    }

    fn registry_read(&self) -> Vec<String> {
        if !self.registry {
            return vec![];
        }
        run("reg", &["query", REGISTRY_KEY, "/v", &self.product])
            .lines()
            .find_map(|l| l.split_once("REG_SZ").map(|(_, v)| v.trim().to_string()))
            .filter(|v| !v.is_empty())
            .into_iter()
            .collect()
    }

    fn registry_write(&self, text: &str) -> bool {
        self.registry
            && Command::new("reg")
                .args(["add", REGISTRY_KEY, "/v", &self.product, "/t", "REG_SZ", "/d", text.trim_end(), "/f"])
                .output()
                .is_ok_and(|o| o.status.success())
    }

    fn copies(&self) -> (Vec<Map<String, Value>>, bool) {
        let mut texts: Vec<String> = self.paths().iter().filter_map(|p| fs::read_to_string(p).ok()).collect();
        texts.extend(self.registry_read());
        let mut good = vec![];
        let mut altered = false;
        for text in texts {
            match self.open(&text) {
                Some(record) => good.push(record),
                None => altered = true,
            }
        }
        (good, altered)
    }

    fn write_all(&self, record: &Map<String, Value>) -> usize {
        let text = self.sealed(record);
        let mut written = self.paths().iter().filter(|p| write_private(p, &text).is_ok()).count();
        if self.registry_write(&text) {
            written += 1;
        }
        written
    }

    fn merged(&self) -> (Option<Map<String, Value>>, bool) {
        let (good, altered) = self.copies();
        let Some(first) = good.iter().min_by_key(|r| text(r, "started_at")) else {
            return (None, altered);
        };
        let mut merged = first.clone();
        let seen = good.iter().map(|r| text(r, "last_seen")).max().unwrap_or_default();
        merged.insert("last_seen".into(), Value::String(seen));
        if let Some(ended) = good.iter().find_map(|r| r.get("ended").filter(|v| !v.is_null() && v != &&Value::Bool(false) && v != &&Value::String(String::new()))) {
            merged.insert("ended".into(), Value::String(ended.as_str().map_or_else(|| ended.to_string(), str::to_string)));
        }
        (Some(merged), altered)
    }

    fn ended(&self, record: Option<&Map<String, Value>>, why: String, final_: bool) -> TrialStatus {
        let get = |key: &str| record.map(|r| text(r, key)).unwrap_or_default();
        TrialStatus {
            product: self.product.clone(),
            state: "ended".into(),
            days: self.days,
            started_at: get("started_at"),
            ends_at: get("ends_at"),
            reference: get("reference"),
            why,
            final_,
        }
    }

    /// Where the trial stands, read from every copy. Changes nothing.
    pub fn status(&self, now: DateTime<Utc>) -> TrialStatus {
        let label = &self.label;
        let (record, altered) = self.merged();
        if altered {
            return self.ended(
                record.as_ref(),
                "a record of the trial on this machine was altered, so the trial has ended".into(),
                true,
            );
        }
        let Some(record) = record else {
            if (self.used_before)() {
                return self.ended(
                    None,
                    format!("{label} has been used on this machine before; the trial was for its first use"),
                    true,
                );
            }
            return TrialStatus {
                product: self.product.clone(),
                state: "available".into(),
                days: self.days,
                started_at: String::new(),
                ends_at: String::new(),
                reference: String::new(),
                why: String::new(),
                final_: true,
            };
        };
        let (started, ends) = (when(record.get("started_at")), when(record.get("ends_at")));
        let seen = when(record.get("last_seen")).or(started);
        let (Some(_), Some(ends)) = (started, ends) else {
            return self.ended(Some(&record), format!("the {label} trial's record is unreadable"), true);
        };
        if let Some(ended) = record.get("ended").and_then(Value::as_str).filter(|s| !s.is_empty()) {
            return self.ended(Some(&record), ended.to_string(), true);
        }
        if seen.is_some_and(|seen| now < seen - Duration::hours(CLOCK_SLACK_HOURS)) {
            return self.ended(
                Some(&record),
                format!("the computer's clock is behind the last time {label} ran: set the date and time right to go on"),
                false,
            );
        }
        if now > ends {
            return self.ended(
                Some(&record),
                format!("the {}-day {label} trial ended on {}", self.days, ends.date_naive()),
                true,
            );
        }
        TrialStatus {
            product: self.product.clone(),
            state: "active".into(),
            days: self.days,
            started_at: text(&record, "started_at"),
            ends_at: text(&record, "ends_at"),
            reference: text(&record, "reference"),
            why: String::new(),
            final_: true,
        }
    }

    /// Start the trial if it has never been used here; otherwise say where it stands.
    pub fn start(&self, now: DateTime<Utc>) -> TrialStatus {
        if self.status(now).state != "available" {
            return self.touch(now);
        }
        let raw = random_hex(16).to_uppercase();
        let mut record = Map::new();
        record.insert("v".into(), json!(VERSION));
        record.insert("product".into(), json!(self.product));
        record.insert("machine".into(), json!(self.machine));
        record.insert(
            "reference".into(),
            json!(format!("TRIAL-{}-{}-{}-{}", &raw[..4], &raw[4..8], &raw[8..12], &raw[12..])),
        );
        record.insert("started_at".into(), json!(iso(now)));
        record.insert("ends_at".into(), json!(iso(now + Duration::days(self.days))));
        record.insert("last_seen".into(), json!(iso(now)));
        if self.write_all(&record) == 0 {
            return self.ended(None, "the trial could not be recorded on this machine".into(), true);
        }
        self.status(now)
    }

    pub fn machine(&self) -> &str {
        &self.machine
    }

    pub fn product(&self) -> &str {
        &self.product
    }

    /// Bring the trial's end forward to `ends_at` when that is earlier (the store's record of this
    /// computer's first trial: activation::anchor_trial). Never moves it later.
    pub fn no_later_than(&self, ends_at: &str, started_at: &str, now: DateTime<Utc>) -> TrialStatus {
        let (record, _) = self.merged();
        let ends = when(Some(&Value::String(ends_at.to_string())));
        let Some(mut record) = record else {
            return self.status(now);
        };
        let current = when(record.get("ends_at"));
        let (Some(ends), Some(current)) = (ends, current) else {
            return self.status(now);
        };
        if ends >= current {
            return self.status(now);
        }
        record.insert("ends_at".into(), json!(iso(ends)));
        let start = when(Some(&Value::String(started_at.to_string())));
        if let (Some(start), Some(began)) = (start, when(record.get("started_at"))) {
            if start < began {
                record.insert("started_at".into(), json!(iso(start)));
            }
        }
        self.write_all(&record);
        self.touch(now)
    }

    /// Record that ELI VR is running now, and write back any copy that is missing, so deleting
    /// some copies never helps. An ended trial stays ended.
    pub fn touch(&self, now: DateTime<Utc>) -> TrialStatus {
        let (record, _) = self.merged();
        let status = self.status(now);
        let Some(mut record) = record else {
            return status;
        };
        if status.state == "ended" && status.final_ && !record.contains_key("ended") {
            record.insert("ended".into(), json!(status.why));
        }
        let stamp = iso(now);
        if status.active() && stamp > text(&record, "last_seen") {
            record.insert("last_seen".into(), json!(stamp));
        }
        self.write_all(&record);
        self.status(now)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const VECTORS: &str = include_str!("../tests/trial_vectors.json");

    fn vectors() -> Value {
        serde_json::from_str(VECTORS).unwrap()
    }

    fn at(text: &str) -> DateTime<Utc> {
        DateTime::parse_from_rfc3339(text).unwrap().with_timezone(&Utc)
    }

    fn trial_in(dir: &Path, machine: &str, used: bool) -> LocalTrial {
        LocalTrial {
            product: "vr".into(),
            label: "ELI VR".into(),
            days: TRIAL_DAYS,
            machine: machine.into(),
            locations: vec![dir.join("a"), dir.join("b"), dir.join("c")],
            used_before: Box::new(move || used),
            registry: false,
        }
    }

    fn scratch(name: &str) -> PathBuf {
        let dir = env::temp_dir().join(format!("eli-vr-trial-{name}-{}", random_hex(8)));
        fs::create_dir_all(&dir).unwrap();
        dir
    }

    #[test]
    fn hmac_matches_rfc_4231_case_2() {
        let mac = hmac_sha256(b"Jefe", b"what do ya want for nothing?");
        assert_eq!(hex(&mac), "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843");
    }

    #[test]
    fn fingerprint_is_eli_sdks() {
        let v = vectors();
        let inputs: Vec<&str> = v["fingerprint_inputs"].as_array().unwrap().iter().map(|x| x.as_str().unwrap()).collect();
        assert_eq!(fingerprint_of(inputs[0], inputs[1], inputs[2]), v["fingerprint"].as_str().unwrap());
    }

    #[test]
    fn seal_and_record_are_eli_sdks() {
        let v = vectors();
        let dir = scratch("seal");
        let trial = trial_in(&dir, v["fingerprint"].as_str().unwrap(), false);
        let record = v["record"].as_object().unwrap().clone();
        assert_eq!(trial.seal(&record), v["seal"].as_str().unwrap());
        assert_eq!(trial.sealed(&record), v["sealed_text"].as_str().unwrap());
        assert_eq!(trial.open(v["sealed_text"].as_str().unwrap()), Some(record));
        let _ = fs::remove_dir_all(dir);
    }

    #[test]
    fn a_record_eli_sdk_wrote_is_read_as_eli_sdk_reads_it() {
        let v = vectors();
        let dir = scratch("read");
        let trial = trial_in(&dir, v["fingerprint"].as_str().unwrap(), false);
        for path in trial.paths() {
            fs::create_dir_all(path.parent().unwrap()).unwrap();
            fs::write(&path, v["sealed_text"].as_str().unwrap()).unwrap();
        }
        let got = trial.status(at("2026-11-21T12:00:00+00:00"));
        assert!(got.active());
        assert_eq!(got.days_left(at("2026-11-21T12:00:00+00:00")), 6);
        assert_eq!(trial.status(at("2026-11-28T00:00:00+00:00")).state, "ended");
        // a clock more than six hours behind the last run stops it, without ending it for good
        let behind = trial.status(at("2026-11-21T03:00:00+00:00"));
        assert_eq!((behind.state.as_str(), behind.final_), ("ended", false));
        let _ = fs::remove_dir_all(dir);
    }

    #[test]
    fn first_use_starts_seven_days_and_deleting_copies_does_not_restart_it() {
        let dir = scratch("start");
        let trial = trial_in(&dir, "machine-a", false);
        let now = at("2026-11-26T10:00:00+00:00");
        assert_eq!(trial.status(now).state, "available");
        let started = trial.start(now);
        assert!(started.active());
        assert_eq!(started.days_left(now), 7);
        let paths = trial.paths();
        fs::remove_file(&paths[0]).unwrap();
        fs::remove_file(&paths[1]).unwrap();
        let later = at("2026-11-27T10:00:00+00:00");
        let again = trial.start(later);
        assert_eq!(again.started_at, started.started_at);
        assert!(paths.iter().all(|p| p.is_file()), "missing copies are written back");
        let _ = fs::remove_dir_all(dir);
    }

    #[test]
    fn an_altered_copy_or_another_machines_copy_ends_it() {
        let dir = scratch("altered");
        let trial = trial_in(&dir, "machine-a", false);
        let now = at("2026-11-26T10:00:00+00:00");
        trial.start(now);
        let path = &trial.paths()[2];
        let edited = fs::read_to_string(path).unwrap().replace("2026-12-03", "2027-12-03");
        fs::write(path, edited).unwrap();
        assert_eq!(trial.status(now).state, "ended");
        let other = trial_in(&dir, "machine-b", false);
        assert_eq!(other.status(now).state, "ended", "a copy from another machine does not verify");
        let _ = fs::remove_dir_all(dir);
    }

    #[test]
    fn no_new_trial_once_eli_vr_has_been_used_here() {
        let dir = scratch("used");
        let trial = trial_in(&dir, "machine-a", true);
        let got = trial.start(at("2026-11-26T10:00:00+00:00"));
        assert_eq!(got.state, "ended");
        assert!(got.why.contains("used on this machine before"));
        let _ = fs::remove_dir_all(dir);
    }
}

#[cfg(test)]
mod this_machine {
    /// `cargo test -- --ignored --nocapture this_machine`: the fingerprint of the machine it runs
    /// on, to compare with `python -c "from eli_sdk.machine import fingerprint; print(fingerprint())"`.
    #[test]
    #[ignore]
    fn this_machine_fingerprint() {
        println!("fingerprint={}", super::fingerprint());
        println!("account_home={}", super::account_home().display());
    }
}
