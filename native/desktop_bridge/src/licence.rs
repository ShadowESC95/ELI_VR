//! Whether this copy of ELI VR may run.
//!
//! The same keys, folder and rules as every ELI product (the ELI SDK is the reference): a key of
//! ELI VR's own, or an ELI v3 key that includes ELI VR, checked offline against ELI's public key.
//! Godot can't verify Ed25519, so the app asks this program.

use std::{
    collections::BTreeMap,
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
const LEGACY_MAJOR: i64 = 3;
const TIERS: [&str; 4] = ["trial", "personal", "pro", "enterprise"];
const OFFICIAL_BUNDLES: [(&str, &str); 4] = [
    ("legal", "ELI Legal"),
    ("vr", "ELI VR"),
    ("healthcare", "ELI Healthcare"),
    ("finance", "ELI Finance"),
];
const ELI_PUB: &str = include_str!("../eli.pub");
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
}

impl License {
    pub fn expired(&self, now: DateTime<Utc>) -> bool {
        when(&self.expires_at).is_some_and(|ends| now > ends)
    }

    pub fn to_json(&self) -> Value {
        json!({
            "license_id": self.license_id, "tier": self.tier, "seats": self.seats,
            "issued_at": self.issued_at, "product": self.product,
            "major_version": self.major_version, "includes": self.includes,
            "expires_at": self.expires_at, "customer_ref": self.customer_ref,
            "format": self.format,
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

/// Verify a key and return what it grants.
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
    public_key
        .verify_strict(&body, &signature)
        .map_err(|_| invalid("the key's signature is invalid"))?;
    let raw: Value =
        serde_json::from_slice(&body).map_err(|_| invalid("the key's contents are not JSON"))?;
    let raw = raw
        .as_object()
        .ok_or_else(|| invalid("the key's contents are not an object"))?;
    license(raw)
}

fn license(raw: &serde_json::Map<String, Value>) -> Result<License, InvalidKey> {
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
    };

    if lic.format != PLATFORM_FORMAT && lic.format != PRODUCT_FORMAT {
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
    if lic.format != expected {
        return Err(invalid("the key's format does not match its product"));
    }
    if lic.major_version < 1 {
        return Err(invalid("the key names no version line"));
    }
    if !lic.includes.is_empty() {
        if lic.product != PLATFORM {
            return Err(invalid("only an ELI v3 key can include bundles"));
        }
        for (name, line) in &lic.includes {
            if !is_bundle(name) {
                return Err(invalid(format!(
                    "included product '{name}' is not an official bundle"
                )));
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

/// Whether the licences cover a product, at a version if one is given. A key covers its
/// version line and every earlier one.
pub fn entitlement(
    product: &str,
    held: &[License],
    version: Option<&str>,
    now: DateTime<Utc>,
) -> Entitlement {
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

    for lic in held.iter().filter(|l| l.product == product) {
        if lic.expired(now) {
            reason = format!("the {label} licence has expired");
        } else if line.is_some_and(|line| lic.major_version < line) {
            reason = format!(
                "your {label} licence covers {label} {}.x; {version} needs an upgrade",
                lic.major_version
            );
        } else {
            return grant(format!("{label} licence"), lic, false);
        }
    }

    if product != PLATFORM {
        for lic in held.iter().filter(|l| l.product == PLATFORM) {
            let Some(&covered) = lic.includes.get(&product) else {
                continue;
            };
            if lic.expired(now) {
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

    pub fn entitlement(
        &self,
        product: &str,
        public_key: &VerifyingKey,
        version: Option<&str>,
    ) -> Entitlement {
        entitlement(product, &self.licenses(public_key), version, Utc::now())
    }

    /// Verify a key and keep it, replacing any key held for the same product.
    pub fn add(&self, key: &str, public_key: &VerifyingKey) -> Result<License, InvalidKey> {
        let lic = read_key(key, public_key)?;
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
        let written = write_private(&tmp, &format!("{}\n", normalize(key)))
            .and_then(|()| fs::rename(&tmp, self.path(&lic.product)));
        if written.is_err() {
            let _ = fs::remove_file(&tmp);
        }
        written.map_err(kept)?;
        Ok(lic)
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
            (false, "the ELI VR licence has expired")
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
}
