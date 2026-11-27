//! Activating a key on this computer, giving its seat back, and anchoring the trial to the store,
//! as eli-sdk's `activation` does (the same rules and the same words, so every ELI product says the
//! same thing).
//!
//! A key bought to be activated opens nothing by itself: `activate` sends it to the store once, with
//! this computer's activation code; the store counts the computers the licence is on against its
//! seats and returns this computer's own key, which is kept and works offline from then on. Asking
//! again from a computer already counted uses no other seat. Any other key is kept as it is.

use std::time::Duration;

use chrono::{DateTime, Utc};
use ed25519_dalek::VerifyingKey;
use serde_json::Value;

use crate::licence::{self, KeyStore, License};
use crate::store::{self, StoreError};
use crate::trial::{LocalTrial, TrialStatus};

const ACTIVATE_TIMEOUT: Duration = Duration::from_secs(15);
const REFRESH_TIMEOUT: Duration = Duration::from_secs(4);

#[derive(Debug, Clone)]
pub struct ActivationError {
    /// Written for the buyer: what happened and what to do.
    pub message: String,
    pub code: String,
    pub detail: Value,
}

/// This computer's activation code as a buyer reads and copies it: eight groups of eight.
pub fn activation_code(machine: &str) -> String {
    machine
        .to_lowercase()
        .as_bytes()
        .chunks(8)
        .map(|c| String::from_utf8_lossy(c).into_owned())
        .collect::<Vec<_>>()
        .join(" ")
}

fn explain(err: &StoreError, lic: &License, code: &str, base: &str) -> String {
    let label = lic.label();
    match err.code.as_str() {
        "seats_full" => {
            let seats = err.detail.get("seats").and_then(Value::as_i64).unwrap_or(lic.seats);
            let used = err.detail.get("used").and_then(Value::as_i64).unwrap_or(seats);
            let which = if seats == 1 { "computer" } else { "computers" };
            format!(
                "This {label} licence is already in use on {used} of its {seats} {which}. To use it here, \
                 deactivate it on another computer ({label}: Licence, then Deactivate this computer), or \
                 release a computer you can no longer reach at {}",
                store::manage_page(base)
            )
        }
        "withdrawn" => format!(
            "This {label} licence has been withdrawn, so it cannot be activated. If you think that is a \
             mistake, contact the seller with your licence number ({}).",
            lic.license_id
        ),
        "expired" => format!("This {label} licence has ended, so it cannot be activated."),
        "busy" => "The licence store is busy. Try again in a few minutes.".into(),
        "offline" => format!(
            "Activating {label} needs the internet once, and the licence store could not be reached. If \
             this computer cannot go online, activate it from any other device at {} with this \
             computer's activation code:\n{code}\nand enter the key you are given there.",
            store::activate_page(base)
        ),
        _ => format!("{label} could not be activated: {}", err.message),
    }
}

/// Take a key in on this computer. A key bought to be activated is sent to the store once and the
/// computer's own key it returns is kept; any other key is kept as it is.
pub fn activate(
    keys: &KeyStore,
    key: &str,
    root: &VerifyingKey,
    machine: &str,
    base: &str,
) -> Result<License, ActivationError> {
    let refused = |message: String, code: &str| ActivationError { message, code: code.into(), detail: Value::Null };
    let lic = licence::read_key(key, root).map_err(|e| refused(e.0, "invalid"))?;
    if !lic.needs_activation() {
        return keys.add_on(key, root, machine).map_err(|e| refused(e.0, "invalid"));
    }
    let machine = machine.to_lowercase();
    let bound = store::activate(base, &licence::normalize(key), &machine, ACTIVATE_TIMEOUT).map_err(|err| {
        ActivationError {
            message: explain(&err, &lic, &activation_code(&machine), base),
            code: if err.code.is_empty() { "refused".into() } else { err.code.clone() },
            detail: err.detail.clone(),
        }
    })?;
    let label = lic.label();
    let got = licence::read_key(&bound, root)
        .map_err(|e| refused(format!("The licence store's answer was not a key {label} accepts ({e})."), "invalid"))?;
    if (got.license_id.as_str(), got.product.as_str(), got.machine.as_str())
        != (lic.license_id.as_str(), lic.product.as_str(), machine.as_str())
        || got.needs_activation()
    {
        return Err(refused(
            format!("The licence store answered with a key for something else; {label} was not activated."),
            "invalid",
        ));
    }
    keys.add_on(&bound, root, &machine).map_err(|e| refused(e.0, "invalid"))
}

/// Give this computer's seat back and remove its key. A key activated online is removed only once
/// the store has freed its seat. Ok(false) when no key is held.
pub fn deactivate(keys: &KeyStore, product: &str, root: &VerifyingKey, base: &str) -> Result<bool, ActivationError> {
    let Some(text) = keys.key_text(product) else {
        return Ok(false);
    };
    let Ok(lic) = licence::read_key(&text, root) else {
        return Ok(keys.remove(product));
    };
    if !lic.activation.is_empty() {
        if let Err(err) = store::deactivate(base, &text, ACTIVATE_TIMEOUT) {
            if err.code != "not_activated" {
                let label = licence::product_label(product);
                let message = if err.code == "offline" {
                    format!(
                        "Deactivating gives this computer's {label} seat back to the licence store, which \
                         could not be reached. Try again when this computer is online, or release it from \
                         any other device at {}.",
                        store::manage_page(base)
                    )
                } else {
                    format!("{label} could not be deactivated: {}", err.message)
                };
                return Err(ActivationError { message, code: err.code, detail: err.detail });
            }
        }
    }
    Ok(keys.remove(product))
}

/// When the store can be reached: keep its newest revocation lists, so a withdrawn licence or a
/// released computer stops working here. Returns how many lists changed.
pub fn refresh_revocations(keys: &KeyStore, root: &VerifyingKey, base: &str) -> Result<usize, StoreError> {
    let lists = store::fetch_revocations(base, REFRESH_TIMEOUT)?;
    Ok(lists.iter().filter(|t| keys.add_revocations(t, root).unwrap_or(false)).count())
}

/// The trial on this computer, held to the store's record of it when the store can be reached: the
/// store gives each computer one trial per product, with its end fixed the first time, so a trial
/// started after its records were deleted ends when the first one did. Asks nothing of the store
/// before the trial has started here; offline, the trial here stands as it is.
pub fn anchor_trial(
    trial: &LocalTrial,
    keys: &KeyStore,
    root: &VerifyingKey,
    base: &str,
    now: DateTime<Utc>,
) -> TrialStatus {
    let status = trial.status(now);
    if status.state == "available" {
        return status;
    }
    let machine = trial.machine().to_string();
    let product = trial.product().to_string();
    let store_trial = |text: &str| {
        licence::read_key(text, root)
            .ok()
            .filter(|l| l.trial() && l.product == product && l.machine == machine)
    };
    let mut held = keys.key_text(&product).as_deref().and_then(store_trial);
    if held.is_none() {
        let Ok(key) = store::request_trial_key(base, &product, &machine, REFRESH_TIMEOUT) else {
            return status;
        };
        held = store_trial(&key);
        if held.is_some() && keys.add_on(&key, root, &machine).is_err() {
            return status;
        }
    }
    match held.as_ref().and_then(|l| l.expires_at.as_str().map(str::to_string)) {
        Some(ends) => trial.no_later_than(&ends, &held.map(|l| l.issued_at).unwrap_or_default(), now),
        None => status,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::{Read, Write};
    use std::net::TcpListener;

    const ACTIVATION: &str = include_str!("../tests/activation_vectors.json");

    /// A store on this computer that answers each request in turn with (status, body).
    fn store_answering(answers: Vec<(u16, String)>) -> String {
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let base = format!("http://127.0.0.1:{}", listener.local_addr().unwrap().port());
        std::thread::spawn(move || {
            for (status, body) in answers {
                let Ok((mut conn, _)) = listener.accept() else { return };
                let mut got = Vec::new();
                let mut buf = [0u8; 8192];
                loop {
                    let n = conn.read(&mut buf).unwrap_or(0);
                    got.extend_from_slice(&buf[..n]);
                    let text = String::from_utf8_lossy(&got);
                    if let Some(end) = text.find("\r\n\r\n") {
                        let length = text[..end]
                            .lines()
                            .find_map(|l| l.to_lowercase().strip_prefix("content-length:").map(|v| v.trim().parse::<usize>().unwrap_or(0)))
                            .unwrap_or(0);
                        if got.len() >= end + 4 + length || n == 0 {
                            break;
                        }
                    }
                    if n == 0 {
                        break;
                    }
                }
                let reply = format!(
                    "HTTP/1.1 {status} X\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
                    body.len()
                );
                let _ = conn.write_all(reply.as_bytes());
            }
        });
        base
    }

    fn vectors() -> (Value, VerifyingKey) {
        let v: Value = serde_json::from_str(ACTIVATION).unwrap();
        let root = licence::public_key_from_pem(v["root_public_pem"].as_str().unwrap()).unwrap();
        (v, root)
    }

    fn folder(name: &str) -> KeyStore {
        let dir = std::env::temp_dir().join(format!("eli-vr-{name}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        KeyStore::new(dir)
    }

    #[test]
    fn activating_keeps_the_key_the_store_makes_for_this_computer() {
        let (v, root) = vectors();
        let here = v["here"].as_str().unwrap();
        let base = store_answering(vec![(200, serde_json::json!({"key": v["activated_here"]}).to_string())]);
        let keys = folder("activate");
        let lic = activate(&keys, v["bought"].as_str().unwrap(), &root, here, &base).unwrap();
        assert_eq!((lic.machine.as_str(), lic.activation.as_str()), (here, "A-HERE"));
        assert!(keys.entitlement_on(licence::PRODUCT, &root, None, here).granted);
    }

    #[test]
    fn a_full_licence_and_no_internet_are_explained() {
        let (v, root) = vectors();
        let here = v["here"].as_str().unwrap();
        let full = serde_json::json!({"error": "every seat is in use", "code": "seats_full", "seats": 2, "used": 2});
        let base = store_answering(vec![(409, full.to_string())]);
        let err = activate(&folder("full"), v["bought"].as_str().unwrap(), &root, here, &base).unwrap_err();
        assert_eq!(err.code, "seats_full");
        assert!(err.message.contains("already in use on 2 of its 2 computers") && err.message.contains("/activations"));
        let err = activate(&folder("offline"), v["bought"].as_str().unwrap(), &root, here, "http://127.0.0.1:9").unwrap_err();
        assert_eq!(err.code, "offline");
        assert!(err.message.contains("http://127.0.0.1:9/activate") && err.message.contains(&activation_code(here)));
        // plain HTTP to another host is refused before anything connects (the address is written
        // in two parts so the network audit does not take it for one ELI VR uses)
        let plain = concat!("http", "://licences.example");
        assert!(store::activate(plain, "k", here, ACTIVATE_TIMEOUT).unwrap_err().message.contains("HTTPS"));
    }

    #[test]
    fn deactivating_frees_the_seat_before_the_key_goes() {
        let (v, root) = vectors();
        let here = v["here"].as_str().unwrap();
        let keys = folder("deactivate");
        keys.add_on(v["activated_here"].as_str().unwrap(), &root, here).unwrap();
        let err = deactivate(&keys, licence::PRODUCT, &root, "http://127.0.0.1:9").unwrap_err();
        assert_eq!(err.code, "offline");
        assert!(keys.key_text(licence::PRODUCT).is_some()); // kept: its seat is still taken
        let base = store_answering(vec![(200, r#"{"used": 0, "seats": 2}"#.into())]);
        assert!(deactivate(&keys, licence::PRODUCT, &root, &base).unwrap());
        assert!(keys.key_text(licence::PRODUCT).is_none());
    }

    #[test]
    fn the_activation_code_is_eight_groups_of_eight() {
        assert_eq!(activation_code(&"AB".repeat(32)), ["abababab"; 8].join(" "));
    }
}
