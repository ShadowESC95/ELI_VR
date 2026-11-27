//! Whether this copy of ELI VR may run.
//!
//! The same keys, folder and rules as every ELI product (the ELI SDK is the reference): a key of
//! ELI VR's own, or an ELI v3 key that includes ELI VR, checked offline against ELI's public key,
//! or signed by an issuer key that ELI's key certified (the store's). A key bound to a computer
//! opens nothing on any other; a key bought to be activated (format 3) opens nothing until the store
//! binds it to this computer (activation.rs); a licence or a single computer's activation that ELI
//! has withdrawn (the signed revocation lists) opens nothing. Godot can't verify Ed25519, so the
//! app asks this program.

use std::{
    collections::{BTreeMap, BTreeSet},
    env, fs,
    io::Write,
    path::{Path, PathBuf},
    time::{SystemTime, UNIX_EPOCH},
};

use base64::{
    Engine, alphabet,
    engine::{DecodePaddingMode, GeneralPurpose, GeneralPurposeConfig, general_purpose::STANDARD},
};
use chrono::{DateTime, NaiveDate, NaiveDateTime, Utc};
use ed25519_dalek::{Signature, VerifyingKey};
use serde_json::{Value, json};

pub const PRODUCT: &str = "vr";
const PLATFORM: &str = "eli";
const PLATFORM_LABEL: &str = "ELI v3";
const PREFIX: &str = "ELIV3-";
const PLATFORM_FORMAT: i64 = 1;
const PRODUCT_FORMAT: i64 = 2;
/// A key bought to be activated, for any product: it opens nothing until the store binds it to one
/// computer. Builds from before it refuse it outright, so it cannot be shared into them.
const ACTIVATION_FORMAT: i64 = 3;
const LEGACY_MAJOR: i64 = 3;
const TIERS: [&str; 4] = ["trial", "personal", "pro", "enterprise"];
const OFFICIAL_BUNDLES: [(&str, &str); 5] = [
    ("legal", "ELI Legal"),
    ("vr", "ELI VR"),
    ("healthcare", "ELI Healthcare"),
    ("finance", "ELI Finance"),
    ("creation", "ELI Creation Station"),
];
const ELI_PUB: &str = include_str!("../eli.pub");
/// The revocation lists shipped in the ELI SDK release this build follows (eli_sdk/revoked.list).
const SHIPPED_REVOCATIONS: &str = include_str!("../revoked.list");
const REVOCATIONS_FILE: &str = "revocations.list";
const SPKI_ED25519: [u8; 12] = [
    0x30, 0x2a, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x70, 0x03, 0x21, 0x00,
];

const B64URL: GeneralPurpose = GeneralPurpose::new(
    &alphabet::URL_SAFE,
    GeneralPurposeConfig::new()
        .with_decode_padding_mode(DecodePaddingMode::Indifferent)
        .with_decode_allow_trailing_bits(true),
);

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct InvalidKey(pub String);

impl std::fmt::Display for InvalidKey {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(&self.0)
    }
}

fn invalid(text: impl Into<String>) -> InvalidKey {
    InvalidKey(text.into())
}

pub fn public_key_from_pem(text: &str) -> Result<VerifyingKey, InvalidKey> {
    let body: String = text.lines().filter(|l| !l.starts_with("-----")).collect();
    let der = STANDARD
        .decode(body.trim())
        .map_err(|_| invalid("not a PEM public key"))?;
    let raw = der
        .strip_prefix(&SPKI_ED25519[..])
        .and_then(|rest| <[u8; 32]>::try_from(rest).ok())
        .ok_or_else(|| invalid("the public key is not an Ed25519 key"))?;
    VerifyingKey::from_bytes(&raw).map_err(|_| invalid("the public key is not an Ed25519 key"))
}

pub fn eli_public_key() -> VerifyingKey {
    public_key_from_pem(ELI_PUB).expect("ELI's public key ships with ELI VR")
}

pub fn product_label(product: &str) -> String {
    if product == PLATFORM {
        return PLATFORM_LABEL.into();
    }
    OFFICIAL_BUNDLES
        .iter()
        .find(|(id, _)| *id == product)
        .map_or_else(|| product.to_string(), |(_, label)| label.to_string())
}

fn is_bundle(product: &str) -> bool {
    OFFICIAL_BUNDLES.iter().any(|(id, _)| *id == product)
}

/// A product id as eli-sdk accepts one (`products.valid_id`): 1-48 characters, lowercase letters,
/// digits, `_` and `-`, starting with a letter or digit.
fn valid_id(value: &str) -> bool {
    let mut chars = value.chars();
    let first_ok = chars.next().is_some_and(|c| c.is_ascii_lowercase() || c.is_ascii_digit());
    first_ok
        && value.len() <= 48
        && value.chars().all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '_' || c == '-')
}

pub fn normalize(key: &str) -> String {
    let text = key.trim();
    match text.get(..PREFIX.len()) {
        Some(head) if head.eq_ignore_ascii_case(PREFIX) => {
            format!("{PREFIX}{}", text[PREFIX.len()..].trim())
        }
        _ => text.to_string(),
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct License {
    pub license_id: String,
    pub tier: String,
    pub seats: i64,
    pub issued_at: String,
    pub product: String,
    pub major_version: i64,
    pub includes: BTreeMap<String, i64>,
    pub expires_at: Value,
    pub customer_ref: Value,
    pub format: i64,
    /// The one computer it works on (its fingerprint), or "" for any.
    pub machine: String,
    /// The store's id for this computer's activation of the licence, or "".
    pub activation: String,
    /// Who signed it: "" for ELI's own key, otherwise the certified issuer's id.
    pub issuer_id: String,
}

impl License {
    pub fn expired(&self, now: DateTime<Utc>) -> bool {
        when(&self.expires_at).is_some_and(|ends| now > ends)
    }

    /// A key bought to be activated: it opens nothing until the store binds it to a computer.
    pub fn needs_activation(&self) -> bool {
        self.format == ACTIVATION_FORMAT
    }

    pub fn trial(&self) -> bool {
        self.tier == "trial"
    }

    /// The key names a computer, and it is not this one.
    pub fn bound_elsewhere(&self, machine: Option<&str>) -> bool {
        !self.machine.is_empty() && machine.is_some_and(|m| self.machine != m.to_lowercase())
    }

    pub fn label(&self) -> String {
        product_label(&self.product)
    }

    pub fn to_json(&self) -> Value {
        json!({
            "license_id": self.license_id, "tier": self.tier, "seats": self.seats,
            "issued_at": self.issued_at, "product": self.product,
            "major_version": self.major_version, "includes": self.includes,
            "expires_at": self.expires_at, "customer_ref": self.customer_ref,
            "format": self.format, "machine": self.machine, "activation": self.activation,
            "issuer_id": self.issuer_id, "needs_activation": self.needs_activation(),
        })
    }
}

fn truthy(value: Option<&Value>) -> bool {
    match value {
        None | Some(Value::Null) => false,
        Some(Value::Bool(b)) => *b,
        Some(Value::Number(n)) => n.as_f64() != Some(0.0),
        Some(Value::String(s)) => !s.is_empty(),
        Some(Value::Array(a)) => !a.is_empty(),
        Some(Value::Object(o)) => !o.is_empty(),
    }
}

fn text_of(value: &Value) -> String {
    match value {
        Value::String(s) => s.clone(),
        Value::Bool(true) => "True".into(),
        Value::Bool(false) => "False".into(),
        Value::Null => "None".into(),
        other => other.to_string(),
    }
}

fn int_of(value: &Value) -> Option<i64> {
    match value {
        Value::Number(n) => n.as_i64().or_else(|| {
            n.as_f64()
                .filter(|f| f.is_finite())
                .map(|f| f.trunc() as i64)
        }),
        Value::Bool(b) => Some(i64::from(*b)),
        Value::String(s) => s.trim().replace('_', "").parse().ok(),
        _ => None,
    }
}

fn when(value: &Value) -> Option<DateTime<Utc>> {
    if !truthy(Some(value)) {
        return None;
    }
    let text = text_of(value).replace('Z', "+00:00");
    for format in [
        "%Y-%m-%dT%H:%M:%S%.f%:z",
        "%Y-%m-%d %H:%M:%S%.f%:z",
        "%Y-%m-%dT%H:%M%:z",
        "%Y-%m-%d %H:%M%:z",
    ] {
        if let Ok(moment) = DateTime::parse_from_str(&text, format) {
            return Some(moment.with_timezone(&Utc));
        }
    }
    for format in [
        "%Y-%m-%dT%H:%M:%S%.f",
        "%Y-%m-%d %H:%M:%S%.f",
        "%Y-%m-%dT%H:%M",
        "%Y-%m-%d %H:%M",
    ] {
        if let Ok(moment) = NaiveDateTime::parse_from_str(&text, format) {
            return Some(moment.and_utc());
        }
    }
    NaiveDate::parse_from_str(&text, "%Y-%m-%d")
        .ok()
        .and_then(|day| day.and_hms_opt(0, 0, 0))
        .map(|moment| moment.and_utc())
}

fn shaped(text: &str) -> Option<(&str, &str)> {
    let rest = text.strip_prefix(PREFIX)?;
    let (body, signature) = rest.split_once('.')?;
    let ok = |part: &str| {
        !part.is_empty()
            && part
                .bytes()
                .all(|b| b.is_ascii_alphanumeric() || b == b'_' || b == b'-')
    };
    (ok(body) && ok(signature)).then_some((body, signature))
}

/// An issuer key ELI's own key vouches for (`ELICERT-…`): keys it signs inside its period, for
/// the products it names, are ELI keys. The store signs with one; ELI's own key stays offline.
#[derive(Debug, Clone)]
pub struct Certificate {
    pub issuer_id: String,
    pub public_key: VerifyingKey,
    pub not_before: DateTime<Utc>,
    pub not_after: DateTime<Utc>,
    pub products: Vec<String>,
    pub may_revoke: bool,
}

impl Certificate {
    fn covers(&self, product: &str) -> bool {
        self.products.iter().any(|p| p == "*" || p == product)
    }

    fn valid_at(&self, moment: &Value) -> bool {
        when(moment).is_some_and(|m| self.not_before <= m && m <= self.not_after)
    }
}

/// `PREFIX<body>.<signature>` split and decoded, the prefix in any case (as eli-sdk's `_split`).
fn split_token(token: &str, prefix: &str, what: &str) -> Result<(Vec<u8>, Signature), InvalidKey> {
    let text = token.trim();
    let head = text.get(..prefix.len()).filter(|h| h.eq_ignore_ascii_case(prefix));
    let rest = head.map(|_| &text[prefix.len()..]).ok_or_else(|| invalid(format!("not an ELI {what}")))?;
    let (body, sig) = rest
        .split_once('.')
        .filter(|(_, s)| !s.contains('.'))
        .ok_or_else(|| invalid(format!("not an ELI {what}")))?;
    let decode = |part: &str| B64URL.decode(part).map_err(|_| invalid(format!("the {what} is not valid base64")));
    let signature = Signature::from_slice(&decode(sig)?).map_err(|_| invalid(format!("the {what}'s signature is invalid")))?;
    Ok((decode(body)?, signature))
}

fn json_object(body: &[u8], what: &str) -> Result<serde_json::Map<String, Value>, InvalidKey> {
    let raw: Value = serde_json::from_slice(body).map_err(|_| invalid(format!("the {what}'s contents are not JSON")))?;
    match raw {
        Value::Object(map) => Ok(map),
        _ => Err(invalid(format!("the {what}'s contents are not an object"))),
    }
}

/// Verify an issuer certificate against ELI's key.
pub fn read_certificate(token: &str, root: &VerifyingKey) -> Result<Certificate, InvalidKey> {
    let (body, signature) = split_token(token, "ELICERT-", "issuer certificate")?;
    root.verify_strict(&body, &signature)
        .map_err(|_| invalid("the issuer certificate is not signed by ELI"))?;
    let raw = json_object(&body, "issuer certificate")?;
    if raw.get("type").and_then(Value::as_str) != Some("eli-issuer") {
        return Err(invalid("not an issuer certificate"));
    }
    let incomplete = |what: &str| invalid(format!("the issuer certificate is incomplete ({what})"));
    let public = raw
        .get("public_key")
        .and_then(Value::as_str)
        .and_then(|k| B64URL.decode(k).ok())
        .and_then(|k| <[u8; 32]>::try_from(k.as_slice()).ok())
        .and_then(|k| VerifyingKey::from_bytes(&k).ok())
        .ok_or_else(|| incomplete("public_key"))?;
    let date = |name: &str| {
        raw.get(name)
            .and_then(when)
            .ok_or_else(|| invalid("the issuer certificate's dates are unreadable"))
    };
    let products = match raw.get("products") {
        Some(Value::Array(list)) if !list.is_empty() => list.iter().map(|p| text_of(p).to_lowercase()).collect(),
        _ => vec!["*".to_string()],
    };
    Ok(Certificate {
        issuer_id: raw.get("issuer_id").map(text_of).ok_or_else(|| incomplete("issuer_id"))?,
        public_key: public,
        not_before: date("not_before")?,
        not_after: date("not_after")?,
        products,
        may_revoke: truthy(raw.get("may_revoke")),
    })
}

/// Verify a key and return what it grants. Signed by ELI's own key, or by an issuer key ELI's
/// key certified: then the certificate travels in the key, and the key must have been issued
/// while the certificate was valid, for a product it covers.
pub fn read_key(key: &str, public_key: &VerifyingKey) -> Result<License, InvalidKey> {
    let text = normalize(key);
    let (body_part, sig_part) = shaped(&text).ok_or_else(|| invalid("not an ELI licence key"))?;
    let decode = |part: &str| {
        B64URL
            .decode(part)
            .map_err(|_| invalid("the key is not valid base64"))
    };
    let (body, signature) = (decode(body_part)?, decode(sig_part)?);
    let signature =
        Signature::from_slice(&signature).map_err(|_| invalid("the key's signature is invalid"))?;
    if public_key.verify_strict(&body, &signature).is_ok() {
        let raw = json_object(&body, "key")?;
        if truthy(raw.get("issuer")) {
            return Err(invalid("a key signed by ELI's own key carries no issuer certificate"));
        }
        return license(&raw, "");
    }
    let raw = json_object(&body, "key").map_err(|_| invalid("the key's signature is invalid"))?;
    let Some(certificate) = raw.get("issuer").and_then(Value::as_str).filter(|c| !c.is_empty()) else {
        return Err(invalid("the key's signature is invalid"));
    };
    let cert = read_certificate(certificate, public_key)?;
    cert.public_key
        .verify_strict(&body, &signature)
        .map_err(|_| invalid("the key's signature is invalid"))?;
    let lic = license(&raw, &cert.issuer_id)?;
    if !cert.covers(&lic.product) {
        return Err(invalid(format!("issuer '{}' is not certified for {}", cert.issuer_id, lic.label())));
    }
    if !cert.valid_at(&Value::String(lic.issued_at.clone())) {
        return Err(invalid(format!("the key was issued outside issuer '{}''s certificate", cert.issuer_id)));
    }
    Ok(lic)
}

fn license(raw: &serde_json::Map<String, Value>, issuer_id: &str) -> Result<License, InvalidKey> {
    let incomplete = |field: &str| invalid(format!("the key's contents are incomplete ({field})"));
    let field = |name: &str| raw.get(name).ok_or_else(|| incomplete(name));
    let int = |name: &str, fallback: Value| {
        int_of(raw.get(name).unwrap_or(&fallback)).ok_or_else(|| incomplete(name))
    };

    let product = if truthy(raw.get("product")) {
        text_of(&raw["product"]).to_lowercase()
    } else {
        PLATFORM.into()
    };
    let major_version = if truthy(raw.get("major_version")) {
        int("major_version", Value::Null)?
    } else {
        LEGACY_MAJOR
    };
    let mut includes = BTreeMap::new();
    if truthy(raw.get("includes")) {
        let listed = raw["includes"]
            .as_object()
            .ok_or_else(|| incomplete("includes"))?;
        for (name, line) in listed {
            includes.insert(
                name.to_lowercase(),
                int_of(line).ok_or_else(|| incomplete("includes"))?,
            );
        }
    }
    let lic = License {
        license_id: text_of(field("license_id")?),
        tier: text_of(field("tier")?).to_lowercase(),
        seats: int("seats", json!(1))?.max(1),
        issued_at: text_of(field("issued_at")?),
        product,
        major_version,
        includes,
        expires_at: raw.get("expires_at").cloned().unwrap_or(Value::Null),
        customer_ref: raw.get("customer_ref").cloned().unwrap_or(Value::Null),
        format: int("version", json!(PLATFORM_FORMAT))?,
        machine: if truthy(raw.get("machine")) { text_of(&raw["machine"]).to_lowercase() } else { String::new() },
        activation: if truthy(raw.get("activation")) { text_of(&raw["activation"]) } else { String::new() },
        issuer_id: issuer_id.to_string(),
    };

    if ![PLATFORM_FORMAT, PRODUCT_FORMAT, ACTIVATION_FORMAT].contains(&lic.format) {
        return Err(invalid(format!("unsupported key format {}", lic.format)));
    }
    if !TIERS.contains(&lic.tier.as_str()) {
        return Err(invalid(format!("unknown tier '{}'", lic.tier)));
    }
    if lic.product != PLATFORM && !is_bundle(&lic.product) {
        return Err(invalid(format!(
            "this key is for '{}', a product this copy of ELI VR does not know; a newer one may",
            lic.product
        )));
    }
    let expected = if lic.product == PLATFORM {
        PLATFORM_FORMAT
    } else {
        PRODUCT_FORMAT
    };
    if lic.format != expected && !lic.needs_activation() {
        return Err(invalid("the key's format does not match its product"));
    }
    if lic.needs_activation() && (!lic.machine.is_empty() || !lic.activation.is_empty()) {
        return Err(invalid("a key to be activated names no computer"));
    }
    if !lic.activation.is_empty() && lic.machine.is_empty() {
        return Err(invalid("an activation names the computer it is for"));
    }
    if lic.major_version < 1 {
        return Err(invalid("the key names no version line"));
    }
    if lic.trial() && when(&lic.expires_at).is_none() {
        return Err(invalid("a trial key must end"));
    }
    if truthy(Some(&lic.expires_at)) && when(&lic.expires_at).is_none() {
        return Err(invalid("the key's end date is unreadable"));
    }
    if !lic.includes.is_empty() {
        if lic.product != PLATFORM {
            return Err(invalid("only an ELI v3 key can include bundles"));
        }
        // A bundle released after this build (ELI Creation Station, say) is allowed, as eli-sdk and
        // ELI v3 allow it: it grants nothing here, and the key still opens ELI VR. Refusing it
        // would lock out everyone holding an ELI v3 key the day a new bundle went on sale.
        for (name, line) in &lic.includes {
            if name == PLATFORM || !valid_id(name) {
                return Err(invalid(format!("included product '{name}' is not a bundle")));
            }
            if *line < 1 {
                return Err(invalid(format!(
                    "included '{name}' needs a version line of 1 or more"
                )));
            }
        }
    }
    Ok(lic)
}

/// The version line a release belongs to. Releases before 1.0 count as 1.x.
pub fn major_line(version: &str) -> Option<i64> {
    let text = version.trim_start();
    let text = text.strip_prefix('v').unwrap_or(text);
    let digits: String = text.chars().take_while(|c| c.is_ascii_digit()).collect();
    digits.parse::<i64>().ok().map(|major| major.max(1))
}

#[derive(Debug, Clone)]
pub struct Entitlement {
    pub product: String,
    pub granted: bool,
    pub reason: String,
    pub license: Option<License>,
    pub included: bool,
}

/// One signed list of withdrawn licences (`ELIREV-…`): from ELI's own key, or from an issuer that
/// may withdraw the keys it made. It also names single computers' activations released from a
/// licence, which withdraws that computer's key and nothing else.
#[derive(Debug, Clone)]
pub struct RevocationList {
    pub signer: String,
    pub serial: i64,
    pub licences: BTreeSet<String>,
    pub issuers: BTreeSet<String>,
    pub activations: BTreeSet<String>,
    pub token: String,
}

fn strings(raw: &serde_json::Map<String, Value>, name: &str) -> BTreeSet<String> {
    raw.get(name)
        .and_then(Value::as_array)
        .map(|list| list.iter().map(text_of).collect())
        .unwrap_or_default()
}

pub fn read_revocations(token: &str, root: &VerifyingKey) -> Result<RevocationList, InvalidKey> {
    let (body, signature) = split_token(token, "ELIREV-", "revocation list")?;
    let raw = json_object(&body, "revocation list")?;
    if raw.get("type").and_then(Value::as_str) != Some("eli-revocations") {
        return Err(invalid("not a revocation list"));
    }
    let mut signer = String::new();
    if root.verify_strict(&body, &signature).is_ok() {
        if truthy(raw.get("issuer")) {
            return Err(invalid("a list signed by ELI's own key carries no issuer certificate"));
        }
    } else {
        let certificate = raw
            .get("issuer")
            .and_then(Value::as_str)
            .filter(|c| !c.is_empty())
            .ok_or_else(|| invalid("the revocation list is not signed by ELI"))?;
        let cert = read_certificate(certificate, root)?;
        if !cert.may_revoke {
            return Err(invalid(format!("issuer '{}' may not withdraw licences", cert.issuer_id)));
        }
        cert.public_key
            .verify_strict(&body, &signature)
            .map_err(|_| invalid("the revocation list's signature is invalid"))?;
        if !strings(&raw, "issuers").is_empty() {
            return Err(invalid("only ELI's own key withdraws an issuer"));
        }
        signer = cert.issuer_id;
    }
    Ok(RevocationList {
        signer,
        serial: raw.get("serial").and_then(int_of).ok_or_else(|| invalid("the revocation list is incomplete (serial)"))?,
        licences: strings(&raw, "licences"),
        issuers: strings(&raw, "issuers"),
        activations: strings(&raw, "activations"),
        token: token.trim().to_string(),
    })
}

/// Every list known, the newest from each signer.
#[derive(Debug, Clone, Default)]
pub struct Revocations {
    lists: BTreeMap<String, RevocationList>,
}

impl Revocations {
    pub fn add(&mut self, rev: RevocationList) -> bool {
        if self.lists.get(&rev.signer).is_some_and(|held| held.serial >= rev.serial) {
            return false;
        }
        self.lists.insert(rev.signer.clone(), rev);
        true
    }

    /// Add every list that verifies; the others are skipped, never trusted.
    pub fn add_tokens<'a>(&mut self, tokens: impl IntoIterator<Item = &'a str>, root: &VerifyingKey) -> usize {
        tokens
            .into_iter()
            .map(str::trim)
            .filter(|t| !t.is_empty() && !t.starts_with('#'))
            .filter_map(|t| read_revocations(t, root).ok())
            .filter(|rev| self.add(rev.clone()))
            .count()
    }

    /// Why this licence is withdrawn, or "" if it is not.
    pub fn why(&self, lic: &License) -> String {
        let label = lic.label();
        let released = format!(
            "this computer's {label} activation has been released; enter the licence key again to activate it here"
        );
        if let Some(own) = self.lists.get("") {
            if own.licences.contains(&lic.license_id) {
                return format!("the {label} licence has been withdrawn");
            }
            if !lic.issuer_id.is_empty() && own.issuers.contains(&lic.issuer_id) {
                return format!("the {label} licence came from an issuer that has been withdrawn");
            }
            if !lic.activation.is_empty() && own.activations.contains(&lic.activation) {
                return released;
            }
        }
        if !lic.issuer_id.is_empty() {
            if let Some(theirs) = self.lists.get(&lic.issuer_id) {
                if theirs.licences.contains(&lic.license_id) {
                    return format!("the {label} licence has been withdrawn");
                }
                if !lic.activation.is_empty() && theirs.activations.contains(&lic.activation) {
                    return released;
                }
            }
        }
        String::new()
    }

    pub fn tokens(&self) -> Vec<String> {
        self.lists.values().map(|r| r.token.clone()).filter(|t| !t.is_empty()).collect()
    }
}

/// Whether the licences cover a product, at a version if one is given. A key covers its
/// version line and every earlier one. (No computer and no withdrawals: tests and the simple case.)
#[cfg(test)]
pub fn entitlement(
    product: &str,
    held: &[License],
    version: Option<&str>,
    now: DateTime<Utc>,
) -> Entitlement {
    entitlement_here(product, held, version, now, None, &Revocations::default())
}

/// As `entitlement`, on this computer (`machine`), with the withdrawals known: a key withdrawn,
/// bound to another computer, or still to be activated covers nothing. A paid key is preferred to
/// a trial.
pub fn entitlement_here(
    product: &str,
    held: &[License],
    version: Option<&str>,
    now: DateTime<Utc>,
    machine: Option<&str>,
    revocations: &Revocations,
) -> Entitlement {
    let mut held: Vec<&License> = held.iter().collect();
    held.sort_by_key(|l| l.trial());
    let unusable = |lic: &License| -> String {
        let withdrawn = revocations.why(lic);
        if !withdrawn.is_empty() {
            return withdrawn;
        }
        if lic.needs_activation() {
            return format!(
                "the {} key has not been activated on this computer: enter it in {} (activating needs the internet once)",
                lic.label(),
                lic.label()
            );
        }
        if lic.bound_elsewhere(machine) {
            return format!("this {} key is for another machine", lic.label());
        }
        String::new()
    };
    let product = product.to_lowercase();
    let label = product_label(&product);
    let line = version.and_then(major_line);
    let version = version.unwrap_or_default();
    let grant = |reason: String, lic: &License, included: bool| Entitlement {
        product: product.clone(),
        granted: true,
        reason,
        license: Some(lic.clone()),
        included,
    };
    let mut reason = format!("no {label} licence");

    for lic in held.iter().copied().filter(|l| l.product == product) {
        let problem = unusable(lic);
        if !problem.is_empty() {
            reason = problem;
        } else if lic.expired(now) {
            reason = if lic.trial() {
                format!("the {label} trial has expired")
            } else {
                format!("the {label} licence has expired")
            };
        } else if line.is_some_and(|line| lic.major_version < line) {
            reason = format!(
                "your {label} licence covers {label} {}.x; {version} needs an upgrade",
                lic.major_version
            );
        } else {
            let what = if lic.trial() { "trial" } else { "licence" };
            return grant(format!("{label} {what}"), lic, false);
        }
    }

    if product != PLATFORM {
        for lic in held.iter().copied().filter(|l| l.product == PLATFORM) {
            let Some(&covered) = lic.includes.get(&product) else {
                continue;
            };
            let problem = unusable(lic);
            if !problem.is_empty() {
                reason = problem;
            } else if lic.expired(now) {
                reason = "the ELI v3 licence that includes it has expired".into();
            } else if line.is_some_and(|line| covered < line) {
                reason = format!(
                    "your ELI v3 licence includes {label} {covered}.x; {version} needs an upgrade"
                );
            } else {
                return grant(
                    format!("{label} is included in your ELI v3 licence"),
                    lic,
                    true,
                );
            }
        }
    }
    Entitlement {
        product,
        granted: false,
        reason,
        license: None,
        included: false,
    }
}

fn home() -> PathBuf {
    ["HOME", "USERPROFILE"]
        .iter()
        .find_map(|name| env::var_os(name).filter(|v| !v.is_empty()))
        .map_or_else(|| PathBuf::from("."), PathBuf::from)
}

fn set_env(name: &str) -> Option<String> {
    env::var(name)
        .ok()
        .map(|v| v.trim().to_string())
        .filter(|v| !v.is_empty())
}

/// Where every ELI product keeps the keys it has been given. ELI_KEYS_DIR overrides it.
pub fn shared_directory() -> PathBuf {
    if let Some(dir) = set_env("ELI_KEYS_DIR") {
        return match dir.strip_prefix('~') {
            Some(rest) if rest.is_empty() || rest.starts_with(['/', '\\']) => {
                home().join(rest.trim_start_matches(['/', '\\']))
            }
            _ => PathBuf::from(dir),
        };
    }
    if cfg!(windows) {
        return set_env("APPDATA")
            .map_or_else(|| home().join("AppData").join("Roaming"), PathBuf::from)
            .join("ELI Keys");
    }
    if cfg!(target_os = "macos") {
        return home()
            .join("Library")
            .join("Application Support")
            .join("ELI Keys");
    }
    set_env("XDG_CONFIG_HOME")
        .map_or_else(|| home().join(".config"), PathBuf::from)
        .join("eli-keys")
}

/// Licence keys kept as files, one per product, in a folder.
pub struct KeyStore {
    pub directory: PathBuf,
}

impl KeyStore {
    pub fn new(directory: impl Into<PathBuf>) -> Self {
        Self {
            directory: directory.into(),
        }
    }

    pub fn shared() -> Self {
        Self::new(shared_directory())
    }

    fn path(&self, product: &str) -> PathBuf {
        self.directory.join(format!("{product}.key"))
    }

    /// Every key held that still verifies. One that doesn't is skipped, never trusted.
    pub fn licenses(&self, public_key: &VerifyingKey) -> Vec<License> {
        let Ok(entries) = fs::read_dir(&self.directory) else {
            return Vec::new();
        };
        let mut paths: Vec<PathBuf> = entries
            .filter_map(|e| e.ok().map(|e| e.path()))
            .filter(|p| p.extension().is_some_and(|x| x == "key") && p.is_file())
            .collect();
        paths.sort();
        paths
            .iter()
            .filter_map(|p| fs::read_to_string(p).ok())
            .filter_map(|text| read_key(&text, public_key).ok())
            .collect()
    }

    /// On this computer, with every withdrawal known.
    pub fn entitlement(
        &self,
        product: &str,
        public_key: &VerifyingKey,
        version: Option<&str>,
    ) -> Entitlement {
        self.entitlement_on(product, public_key, version, &crate::trial::fingerprint())
    }

    pub fn entitlement_on(
        &self,
        product: &str,
        public_key: &VerifyingKey,
        version: Option<&str>,
        machine: &str,
    ) -> Entitlement {
        entitlement_here(
            product,
            &self.licenses(public_key),
            version,
            Utc::now(),
            Some(machine),
            &self.revocations(public_key),
        )
    }

    /// The key held for a product, as it was kept.
    pub fn key_text(&self, product: &str) -> Option<String> {
        fs::read_to_string(self.path(product)).ok().map(|t| t.trim().to_string())
    }

    /// The lists shipped with this build, and every newer one kept in the folder.
    pub fn revocations(&self, public_key: &VerifyingKey) -> Revocations {
        let mut known = Revocations::default();
        known.add_tokens(SHIPPED_REVOCATIONS.lines(), public_key);
        if let Ok(text) = fs::read_to_string(self.directory.join(REVOCATIONS_FILE)) {
            known.add_tokens(text.lines(), public_key);
        }
        known
    }

    /// Keep a revocation list if it verifies and is newer than the one held from its signer.
    pub fn add_revocations(&self, token: &str, public_key: &VerifyingKey) -> Result<bool, InvalidKey> {
        let rev = read_revocations(token, public_key)?;
        let mut known = self.revocations(public_key);
        if !known.add(rev) {
            return Ok(false);
        }
        self.write(REVOCATIONS_FILE, &(known.tokens().join("\n") + "\n"))?;
        Ok(true)
    }

    /// Verify a key and keep it, replacing any key held for the same product. Refused: a key to be
    /// activated (activation.rs keeps the key the store makes of it), one bound to another
    /// computer, one withdrawn, and a trial key offered over a paid key that still works.
    #[cfg(test)]
    pub fn add(&self, key: &str, public_key: &VerifyingKey) -> Result<License, InvalidKey> {
        self.add_on(key, public_key, &crate::trial::fingerprint())
    }

    pub fn add_on(&self, key: &str, public_key: &VerifyingKey, machine: &str) -> Result<License, InvalidKey> {
        let lic = read_key(key, public_key)?;
        let label = lic.label();
        if lic.needs_activation() {
            return Err(invalid(format!(
                "this {label} key must be activated first: enter it in {label} (activating needs the internet once)"
            )));
        }
        if lic.bound_elsewhere(Some(machine)) {
            return Err(invalid(format!("this {label} key is for another machine")));
        }
        let withdrawn = self.revocations(public_key).why(&lic);
        if !withdrawn.is_empty() {
            return Err(invalid(withdrawn));
        }
        if lic.trial() {
            let current = self.key_text(&lic.product).and_then(|t| read_key(&t, public_key).ok());
            if current.is_some_and(|c| !c.trial() && !c.expired(Utc::now())) {
                return Err(invalid(format!("this machine already holds a paid {label} licence")));
            }
        }
        self.write(&format!("{}.key", lic.product), &format!("{}\n", normalize(key)))?;
        Ok(lic)
    }

    fn write(&self, name: &str, text: &str) -> Result<(), InvalidKey> {
        let kept = |e: std::io::Error| {
            invalid(format!(
                "the key could not be kept in {} ({e})",
                self.directory.display()
            ))
        };
        fs::create_dir_all(&self.directory).map_err(kept)?;
        let stamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map_or(0, |d| d.as_nanos());
        let tmp = self
            .directory
            .join(format!(".key-{}-{stamp}", std::process::id()));
        let written = write_private(&tmp, text).and_then(|()| fs::rename(&tmp, self.directory.join(name)));
        if written.is_err() {
            let _ = fs::remove_file(&tmp);
        }
        written.map_err(kept)
    }

    pub fn remove(&self, product: &str) -> bool {
        let path = self.path(product);
        path.is_file() && fs::remove_file(path).is_ok()
    }
}

fn write_private(path: &Path, text: &str) -> std::io::Result<()> {
    let mut options = fs::OpenOptions::new();
    options.write(true).create_new(true);
    #[cfg(unix)]
    std::os::unix::fs::OpenOptionsExt::mode(&mut options, 0o600);
    options.open(path)?.write_all(text.as_bytes())
}

/// What `licence` prints: whether ELI VR may run, and why.
pub fn report(store: &KeyStore, got: &Entitlement) -> Value {
    json!({
        "product": got.product,
        "licensed": got.granted,
        "reason": got.reason,
        "included": got.included,
        "licence": got.license.as_ref().map(License::to_json),
        "directory": store.directory.display().to_string(),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use ed25519_dalek::{Signer, SigningKey};

    const VECTORS: &str = include_str!("../tests/vectors.json");

    fn vectors() -> Value {
        serde_json::from_str(VECTORS).unwrap()
    }

    fn vector_key() -> VerifyingKey {
        public_key_from_pem(vectors()["public_key_pem"].as_str().unwrap()).unwrap()
    }

    struct Issuer(SigningKey);

    impl Issuer {
        fn new() -> Self {
            Self(SigningKey::from_bytes(&[7; 32]))
        }

        fn public(&self) -> VerifyingKey {
            self.0.verifying_key()
        }

        fn key(&self, fields: Value) -> String {
            let mut body = json!({"license_id": "t", "tier": "pro", "seats": 1, "issued_at": "2026-10-15T00:00:00+00:00"});
            let product = fields
                .get("product")
                .and_then(Value::as_str)
                .unwrap_or(PLATFORM)
                .to_string();
            body["version"] = json!(if product == PLATFORM { 1 } else { 2 });
            for (k, v) in fields.as_object().unwrap() {
                body[k] = v.clone();
            }
            let raw = serde_json::to_vec(&body).unwrap();
            let enc = |b: &[u8]| B64URL.encode(b).trim_end_matches('=').to_string();
            format!(
                "{PREFIX}{}.{}",
                enc(&raw),
                enc(&self.0.sign(&raw).to_bytes())
            )
        }
    }

    fn scratch(name: &str) -> KeyStore {
        let dir = env::temp_dir().join(format!("eli-vr-licence-{name}-{}", std::process::id()));
        let _ = fs::remove_dir_all(&dir);
        KeyStore::new(dir)
    }

    #[test]
    fn an_eli_key_including_a_bundle_released_later_still_opens_eli_vr() {
        let issuer = Issuer::new();
        let lic = read_key(
            &issuer.key(json!({"includes": {"vr": 1, "creation": 1}})),
            &issuer.public(),
        )
        .unwrap();
        let got = entitlement("vr", &[lic], None, Utc::now());
        assert!(got.granted, "{}", got.reason);
        assert!(
            read_key(&issuer.key(json!({"includes": {"Not A Bundle": 1}})), &issuer.public()).is_err()
        );
    }

    #[test]
    fn every_vector_reads_as_eli_reads_it() {
        let all = vectors();
        let public = vector_key();
        for (name, case) in all["keys"].as_object().unwrap() {
            let got = read_key(case["key"].as_str().unwrap(), &public);
            if case["valid"] == json!(true) {
                let lic = got.unwrap_or_else(|e| panic!("{name}: {e}"));
                assert_eq!(json!(lic.product), case["product"], "{name}");
                assert_eq!(json!(lic.format), case["format"], "{name}");
                if let Some(major) = case.get("major_version") {
                    assert_eq!(&json!(lic.major_version), major, "{name}");
                }
                if let Some(includes) = case.get("includes") {
                    assert_eq!(&json!(lic.includes), includes, "{name}");
                }
                assert_eq!(
                    lic.expired(Utc::now()),
                    case.get("expired") == Some(&json!(true)),
                    "{name}"
                );
            } else {
                let err = got.expect_err(name).0;
                assert!(
                    err.contains(case["error"].as_str().unwrap()),
                    "{name}: {err}"
                );
            }
        }
    }

    #[test]
    fn eli_public_key_loads() {
        let _ = eli_public_key();
    }

    #[test]
    fn its_own_key_licenses_it() {
        let issuer = Issuer::new();
        let lic = read_key(&issuer.key(json!({"product": "vr"})), &issuer.public()).unwrap();
        let got = entitlement(PRODUCT, &[lic], Some("0.9.2"), Utc::now());
        assert!(got.granted && !got.included, "{}", got.reason);
    }

    #[test]
    fn an_eli_v3_key_that_includes_it_licenses_it_up_to_its_line() {
        let issuer = Issuer::new();
        let lic = read_key(
            &issuer.key(json!({"includes": {"vr": 2}})),
            &issuer.public(),
        )
        .unwrap();
        let held = [lic];
        let got = entitlement(PRODUCT, &held, Some("2.4.0"), Utc::now());
        assert!(got.granted && got.included);
        let got = entitlement(PRODUCT, &held, Some("3.0.0"), Utc::now());
        assert!(!got.granted);
        assert_eq!(
            got.reason,
            "your ELI v3 licence includes ELI VR 2.x; 3.0.0 needs an upgrade"
        );
    }

    #[test]
    fn an_eli_v3_key_without_it_does_not() {
        let issuer = Issuer::new();
        let lic = read_key(
            &issuer.key(json!({"includes": {"legal": 1}})),
            &issuer.public(),
        )
        .unwrap();
        let got = entitlement(PRODUCT, &[lic], Some("0.9.2"), Utc::now());
        assert_eq!(
            (got.granted, got.reason.as_str()),
            (false, "no ELI VR licence")
        );
    }

    #[test]
    fn an_expired_key_does_not() {
        let issuer = Issuer::new();
        let key = issuer
            .key(json!({"product": "vr", "tier": "trial", "expires_at": "2026-01-01T00:00:00Z"}));
        let got = entitlement(
            PRODUCT,
            &[read_key(&key, &issuer.public()).unwrap()],
            None,
            Utc::now(),
        );
        assert_eq!(
            (got.granted, got.reason.as_str()),
            (false, "the ELI VR trial has expired") // eli-sdk's words for a trial key
        );
    }

    #[test]
    fn releases_before_one_count_as_the_first_line() {
        assert_eq!(major_line("0.9.2"), Some(1));
        assert_eq!(major_line("v2.3"), Some(2));
        assert_eq!(major_line("1.0.0-beta.2"), Some(1));
        assert_eq!(major_line("next"), None);
    }

    #[test]
    fn the_store_keeps_one_key_per_product() {
        let issuer = Issuer::new();
        let store = scratch("store");
        store
            .add(&issuer.key(json!({"product": "vr"})), &issuer.public())
            .unwrap();
        store
            .add(
                &format!("  eliv3-{}", &issuer.key(json!({}))[PREFIX.len()..]),
                &issuer.public(),
            )
            .unwrap();
        assert!(
            store.directory.join("vr.key").is_file() && store.directory.join("eli.key").is_file()
        );
        assert_eq!(store.licenses(&issuer.public()).len(), 2);
        assert!(
            store
                .entitlement(PRODUCT, &issuer.public(), Some("0.9.2"))
                .granted
        );
        assert!(store.remove(PRODUCT) && !store.remove(PRODUCT));
        assert!(!store.entitlement(PRODUCT, &issuer.public(), None).granted);
        let _ = fs::remove_dir_all(&store.directory);
    }

    #[test]
    fn a_key_that_does_not_verify_is_never_kept_or_trusted() {
        let issuer = Issuer::new();
        let store = scratch("forged");
        let other = SigningKey::from_bytes(&[9; 32]).verifying_key();
        assert!(
            store
                .add(&issuer.key(json!({"product": "vr"})), &other)
                .is_err()
        );
        assert!(!store.directory.exists());
        fs::create_dir_all(&store.directory).unwrap();
        fs::write(
            store.directory.join("vr.key"),
            issuer.key(json!({"product": "vr"})),
        )
        .unwrap();
        assert!(store.licenses(&other).is_empty());
        let _ = fs::remove_dir_all(&store.directory);
    }

    // ── activation, issuers, computers, revocation (vectors made by eli-sdk) ──
    const ACTIVATION: &str = include_str!("../tests/activation_vectors.json");

    fn av() -> (Value, VerifyingKey) {
        let v: Value = serde_json::from_str(ACTIVATION).unwrap();
        let root = public_key_from_pem(v["root_public_pem"].as_str().unwrap()).unwrap();
        (v, root)
    }

    fn s<'a>(v: &'a Value, name: &str) -> &'a str {
        v[name].as_str().unwrap()
    }

    #[test]
    fn a_key_to_be_activated_opens_nothing_by_itself() {
        let (v, root) = av();
        let lic = read_key(s(&v, "bought"), &root).unwrap();
        assert!(lic.needs_activation() && lic.machine.is_empty() && lic.seats == 2);
        let got = entitlement_here(PRODUCT, &[lic], None, Utc::now(), Some(s(&v, "here")), &Revocations::default());
        assert!(!got.granted && got.reason.contains("has not been activated on this computer"));
        let dir = std::env::temp_dir().join(format!("eli-vr-act-{}", std::process::id()));
        let refused = KeyStore::new(&dir).add_on(s(&v, "bought"), &root, s(&v, "here")).unwrap_err();
        assert!(refused.0.contains("must be activated first"));
        let _ = fs::remove_dir_all(dir);
    }

    #[test]
    fn the_stores_key_for_this_computer_opens_it_here_and_nowhere_else() {
        let (v, root) = av();
        let lic = read_key(s(&v, "activated_here"), &root).unwrap();
        assert_eq!(
            (lic.issuer_id.as_str(), lic.machine.as_str(), lic.activation.as_str(), lic.format),
            ("store-test", s(&v, "here"), "A-HERE", PRODUCT_FORMAT)
        );
        let none = Revocations::default();
        let here = entitlement_here(PRODUCT, std::slice::from_ref(&lic), Some("0.9.25"), Utc::now(), Some(s(&v, "here")), &none);
        let there = entitlement_here(PRODUCT, &[lic], Some("0.9.25"), Utc::now(), Some(s(&v, "there")), &none);
        assert!(here.granted);
        assert_eq!((there.granted, there.reason.as_str()), (false, "this ELI VR key is for another machine"));
    }

    #[test]
    fn an_eli_v3_key_activated_here_opens_eli_vr_here() {
        let (v, root) = av();
        let lic = read_key(s(&v, "eli_activated_here"), &root).unwrap();
        let got = entitlement_here(PRODUCT, &[lic], None, Utc::now(), Some(s(&v, "here")), &Revocations::default());
        assert!(got.granted && got.included);
    }

    #[test]
    fn a_released_computer_and_a_withdrawn_licence_open_nothing() {
        let (v, root) = av();
        let mut known = Revocations::default();
        assert_eq!(known.add_tokens([s(&v, "released_there"), s(&v, "withdrawn_eli"), "ELIREV-x.y"], &root), 2);
        let here = read_key(s(&v, "activated_here"), &root).unwrap();
        let there = read_key(s(&v, "activated_there"), &root).unwrap();
        let eli = read_key(s(&v, "eli_activated_here"), &root).unwrap();
        assert_eq!(known.why(&here), "");
        assert!(known.why(&there).contains("activation has been released"));
        assert_eq!(known.why(&eli), "the ELI v3 licence has been withdrawn");
        let got = entitlement_here(PRODUCT, &[there], None, Utc::now(), Some(s(&v, "there")), &known);
        assert!(!got.granted && got.reason.contains("released"));
    }

    #[test]
    fn revocation_lists_are_kept_in_the_shared_folder() {
        let (v, root) = av();
        let dir = std::env::temp_dir().join(format!("eli-vr-rev-{}", std::process::id()));
        let keys = KeyStore::new(&dir);
        assert!(keys.add_revocations(s(&v, "released_there"), &root).unwrap());
        assert!(!keys.add_revocations(s(&v, "released_there"), &root).unwrap()); // not newer
        assert!(keys.add_revocations("ELIREV-x.y", &root).is_err());
        let there = read_key(s(&v, "activated_there"), &root).unwrap();
        assert!(keys.revocations(&root).why(&there).contains("released"));
        assert!(keys.add_on(s(&v, "activated_there"), &root, s(&v, "there")).unwrap_err().0.contains("released"));
        assert!(keys.add_on(s(&v, "activated_here"), &root, s(&v, "here")).is_ok());
        let _ = fs::remove_dir_all(dir);
    }

    #[test]
    fn an_issuer_signs_only_for_the_products_it_is_certified_for() {
        let (v, root) = av();
        let err = read_key(s(&v, "vr_key_from_legal_only_issuer"), &root).unwrap_err();
        assert!(err.0.contains("not certified for ELI VR"), "{}", err.0);
        // and nothing signed by a stranger is read, certificate or not
        assert!(read_key(s(&v, "activated_here"), &Issuer::new().public()).is_err());
    }
}
