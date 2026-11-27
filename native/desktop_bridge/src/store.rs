//! Talking to ELI's licence store, as eli-sdk's `store` does: activating a key on this computer,
//! giving the seat back, the signed revocation lists, and this computer's trial.
//!
//! HTTPS only (plain HTTP to this computer aside, for tests). What is sent is what each call needs: the
//! licence key and this computer's fingerprint (a one-way hash, nothing about the person), or the
//! product and that fingerprint for the trial. Nothing else, and nothing in the background except
//! `licence refresh`, which the app starts at launch.

use std::time::Duration;

use serde_json::{Value, json};

pub const STORE_URL: &str = "https://licences.geteli.tech";

#[derive(Debug, Clone)]
pub struct StoreError {
    /// The store's reason (`seats_full`, `withdrawn`, `expired`, `invalid`, `not_activated`,
    /// `busy`), or `offline` when it could not be reached.
    pub code: String,
    pub message: String,
    pub detail: Value,
}

impl std::fmt::Display for StoreError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(&self.message)
    }
}

pub fn activate_page(base: &str) -> String {
    format!("{}/activate", base.trim_end_matches('/'))
}

pub fn manage_page(base: &str) -> String {
    format!("{}/activations", base.trim_end_matches('/'))
}

fn offline(message: String) -> StoreError {
    StoreError { code: "offline".into(), message, detail: Value::Null }
}

fn checked(base: &str) -> Result<String, StoreError> {
    let url = base.trim_end_matches('/').to_string();
    let local = ["http://localhost", "http://127.0.0.1", "http://[::1]"]
        .iter()
        .any(|l| url == *l || url.starts_with(&format!("{l}:")) || url.starts_with(&format!("{l}/")));
    if url.starts_with("https://") || local {
        Ok(url)
    } else {
        Err(StoreError {
            code: "invalid".into(),
            message: format!("the store must be reached over HTTPS, not {url}"),
            detail: Value::Null,
        })
    }
}

fn call(method: &str, url: &str, body: Option<&Value>, timeout: Duration) -> Result<Value, StoreError> {
    let agent: ureq::Agent = ureq::Agent::config_builder()
        .timeout_global(Some(timeout))
        .http_status_as_error(false)
        .build()
        .into();
    let sent = match (method, body) {
        ("POST", Some(body)) => agent
            .post(url)
            .header("Accept", "application/json")
            .header("Content-Type", "application/json")
            .header("User-Agent", "eli-vr")
            .send(body.to_string()),
        _ => agent.get(url).header("Accept", "application/json").header("User-Agent", "eli-vr").call(),
    };
    let mut response = sent.map_err(|e| offline(format!("the store could not be reached ({e})")))?;
    let status = response.status().as_u16();
    let text = response
        .body_mut()
        .read_to_string()
        .map_err(|e| offline(format!("the store's answer could not be read ({e})")))?;
    let answer: Value = serde_json::from_str(&text).unwrap_or(Value::Null);
    if !(200..300).contains(&status) {
        let message = answer.get("error").and_then(Value::as_str).unwrap_or("refused").to_string();
        let code = answer.get("code").and_then(Value::as_str).unwrap_or_default().to_string();
        return Err(StoreError { code, message: format!("the store refused: {message}"), detail: answer });
    }
    if answer.is_object() {
        Ok(answer)
    } else {
        Err(offline("the store's answer was not readable".into()))
    }
}

/// This computer's own key for a key bought to be activated (a seat, unless it has one already).
pub fn activate(base: &str, key: &str, machine: &str, timeout: Duration) -> Result<String, StoreError> {
    let url = format!("{}/v1/activate", checked(base)?);
    let answer = call("POST", &url, Some(&json!({"key": key, "machine": machine})), timeout)?;
    answer
        .get("key")
        .and_then(Value::as_str)
        .filter(|k| !k.is_empty())
        .map(str::to_string)
        .ok_or_else(|| StoreError { code: "invalid".into(), message: "the store gave no key".into(), detail: answer })
}

/// Give back the seat of the computer this key (its own) was made for.
pub fn deactivate(base: &str, key: &str, timeout: Duration) -> Result<Value, StoreError> {
    let url = format!("{}/v1/deactivate", checked(base)?);
    call("POST", &url, Some(&json!({"key": key})), timeout)
}

/// The store's current signed revocation lists (verified by the key store before they are kept).
pub fn fetch_revocations(base: &str, timeout: Duration) -> Result<Vec<String>, StoreError> {
    let url = format!("{}/v1/revocations", checked(base)?);
    let answer = call("GET", &url, None, timeout)?;
    Ok(answer
        .get("lists")
        .and_then(Value::as_array)
        .map(|l| l.iter().filter_map(Value::as_str).map(str::to_string).collect())
        .unwrap_or_default())
}

/// This computer's trial key for a product: the same key every time it is asked for.
pub fn request_trial_key(base: &str, product: &str, machine: &str, timeout: Duration) -> Result<String, StoreError> {
    let url = format!("{}/v1/trial", checked(base)?);
    let answer = call("POST", &url, Some(&json!({"product": product, "machine": machine})), timeout)?;
    answer
        .get("key")
        .and_then(Value::as_str)
        .filter(|k| !k.is_empty())
        .map(str::to_string)
        .ok_or_else(|| offline("the store gave no trial key".into()))
}
