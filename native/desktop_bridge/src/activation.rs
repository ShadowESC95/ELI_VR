//! A key for this computer, entirely offline, as every ELI product does it.
//!
//! ELI VR never goes online for its licence. A licence covers a number of computers; for each one,
//! the buyer sends the seller this computer's **activation code** (shown on the licence screen) with
//! their licence number, and gets back this computer's own key, which works here and nowhere else.
//! **Deactivate this computer** removes that key here; the buyer tells the seller, who frees the seat
//! for another computer.

use ed25519_dalek::VerifyingKey;

use crate::licence::{self, KeyStore, License};

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

/// What to do with a licence that still needs this computer's key: the same words in every product.
pub fn ask_the_seller(label: &str, machine: &str) -> String {
    format!(
        "This is the {label} licence, not this computer's key. Send the seller your licence number and \
         this computer's activation code:\n{}\nand enter the key you get back. It works on this computer, \
         with no internet needed.",
        activation_code(machine)
    )
}

/// Take a key in on this computer. Nothing is sent anywhere.
pub fn activate(keys: &KeyStore, key: &str, root: &VerifyingKey, machine: &str) -> Result<License, String> {
    let lic = licence::read_key(key, root).map_err(|e| e.0)?;
    if lic.needs_activation() {
        return Err(ask_the_seller(&lic.label(), machine));
    }
    keys.add_on(key, root, machine).map_err(|e| e.0)
}

/// Remove ELI VR's key from this computer. Ok(false) when none is held.
pub fn deactivate(keys: &KeyStore, product: &str) -> bool {
    keys.key_text(product).is_some() && keys.remove(product)
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::Value;

    const ACTIVATION: &str = include_str!("../tests/activation_vectors.json");

    fn folder(name: &str) -> KeyStore {
        let dir = std::env::temp_dir().join(format!("eli-vr-{name}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        KeyStore::new(dir)
    }

    #[test]
    fn a_licence_asks_for_this_computers_key_and_nothing_is_sent() {
        let v: Value = serde_json::from_str(ACTIVATION).unwrap();
        let root = licence::public_key_from_pem(v["root_public_pem"].as_str().unwrap()).unwrap();
        let here = v["here"].as_str().unwrap();
        let keys = folder("offline");
        let err = activate(&keys, v["bought"].as_str().unwrap(), &root, here).unwrap_err();
        assert!(err.contains("not this computer's key") && err.contains(&activation_code(here)));
        let lic = activate(&keys, v["activated_here"].as_str().unwrap(), &root, here).unwrap();
        assert_eq!(lic.machine, here);
        let there = v["there"].as_str().unwrap();
        assert!(activate(&folder("there"), v["activated_here"].as_str().unwrap(), &root, there)
            .unwrap_err()
            .contains("another machine"));
        assert!(deactivate(&keys, licence::PRODUCT) && !deactivate(&keys, licence::PRODUCT));
    }

    #[test]
    fn the_activation_code_is_eight_groups_of_eight() {
        assert_eq!(activation_code(&"AB".repeat(32)), ["abababab"; 8].join(" "));
    }
}
