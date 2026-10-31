// SPDX-License-Identifier: GPL-3.0-or-later
use super::{authorization, transport::SecurityDescriptor};
use crate::{owned, wide};
use serde::Deserialize;
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::{
    collections::HashSet,
    fs::{self, File, OpenOptions},
    io::{self, Read, Write},
    mem::{size_of, zeroed},
    os::windows::{
        fs::{MetadataExt, OpenOptionsExt},
        io::AsRawHandle,
    },
    path::{Path, PathBuf},
    ptr::null_mut,
};
use windows_sys::Win32::{
    Foundation::*,
    Security::{Cryptography::*, *},
    Storage::FileSystem::*,
};

const MAX_DOCUMENT: usize = 256 * 1024;

#[derive(Clone, Copy, Deserialize)]
#[serde(rename_all = "camelCase")]
enum Document {
    App,
    Language,
    Updates,
}
impl Document {
    fn name(self) -> &'static str {
        match self {
            Self::App => "app-state.json",
            Self::Language => "language.json",
            Self::Updates => "updates.json",
        }
    }
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Request {
    protocol: u32,
    command: String,
    document: Document,
    #[serde(default)]
    revision: Option<String>,
    #[serde(default)]
    value: Option<Value>,
}

#[derive(Debug)]
enum Failure {
    Invalid,
    Stored,
    Conflict,
    Storage(io::Error),
}
impl From<io::Error> for Failure {
    fn from(error: io::Error) -> Self {
        Self::Storage(error)
    }
}
type Result<T> = std::result::Result<T, Failure>;

fn object<'a>(value: &'a Value, fields: &[&str]) -> Result<&'a serde_json::Map<String, Value>> {
    let map = value.as_object().ok_or(Failure::Invalid)?;
    if map.keys().any(|key| !fields.contains(&key.as_str())) {
        return Err(Failure::Invalid);
    }
    Ok(map)
}
fn text(value: &Value, max: usize, optional: bool) -> Result<()> {
    if value.is_null() && optional {
        return Ok(());
    }
    let text = value.as_str().ok_or(Failure::Invalid)?;
    if text.len() > max || text.chars().any(|v| v.is_control()) {
        return Err(Failure::Invalid);
    }
    Ok(())
}
fn boolean(value: &Value) -> Result<()> {
    if value.is_null() || value.is_boolean() {
        Ok(())
    } else {
        Err(Failure::Invalid)
    }
}
fn choice(value: &Value, choices: &[&str]) -> Result<()> {
    if value.is_null() || value.as_str().is_some_and(|v| choices.contains(&v)) {
        Ok(())
    } else {
        Err(Failure::Invalid)
    }
}
fn link(value: &Value, updates: bool) -> Result<()> {
    text(value, 16384, false)?;
    let value = value.as_str().unwrap();
    let (scheme, rest) = value.split_once("://").ok_or(Failure::Invalid)?;
    if rest.is_empty()
        || (updates && scheme != "https")
        || (!updates
            && ![
                "https",
                "hy2",
                "hysteria2",
                "vless",
                "trojan",
                "vmess",
                "ss",
            ]
            .contains(&scheme))
    {
        return Err(Failure::Invalid);
    }
    if scheme == "https" {
        let authority = rest.split(['/', '?', '#']).next().unwrap_or("");
        if authority.is_empty()
            || authority.contains('@')
            || value.chars().any(char::is_whitespace)
            || (updates && value.contains('#'))
        {
            return Err(Failure::Invalid);
        }
    }
    Ok(())
}

fn validate(document: Document, value: &Value) -> Result<()> {
    match document {
        Document::Language => {
            object(value, &["language"])?;
            choice(
                &value["language"],
                &["en", "ru", "zh", "de", "fr", "es", "ar", "fa", "he"],
            )?;
        }
        Document::Updates => {
            object(value, &["automaticChecks", "sources"])?;
            boolean(&value["automaticChecks"])?;
            if !value["sources"].is_null() {
                let sources = value["sources"]
                    .as_array()
                    .filter(|v| v.len() <= 128)
                    .ok_or(Failure::Invalid)?;
                for source in sources {
                    link(source, true)?;
                }
            }
        }
        Document::App => {
            object(
                value,
                &[
                    "version",
                    "subscriptions",
                    "activeSubscriptionUrl",
                    "mode",
                    "core",
                    "dnsProvider",
                    "connectionLeakProtectionEnabled",
                    "statisticsEnabled",
                    "pingType",
                    "routingPolicy",
                ],
            )?;
            if value["version"] != 1 {
                return Err(Failure::Invalid);
            }
            choice(&value["mode"], &["tun", "proxy"])?;
            choice(&value["core"], &["singBox", "xray"])?;
            choice(&value["dnsProvider"], &["cloudflare", "google", "quad9"])?;
            choice(
                &value["pingType"],
                &["icmp", "tcp", "proxyGet", "proxyHead"],
            )?;
            boolean(&value["connectionLeakProtectionEnabled"])?;
            boolean(&value["statisticsEnabled"])?;
            let mut urls = HashSet::new();
            if !value["subscriptions"].is_null() {
                let subscriptions = value["subscriptions"]
                    .as_array()
                    .filter(|v| v.len() <= 1024)
                    .ok_or(Failure::Invalid)?;
                for subscription in subscriptions {
                    object(
                        subscription,
                        &["url", "selectedServerKey", "updatedAt", "expiresAt"],
                    )?;
                    link(&subscription["url"], false)?;
                    if !urls.insert(subscription["url"].as_str().unwrap()) {
                        return Err(Failure::Invalid);
                    }
                    text(&subscription["selectedServerKey"], 16384, true)?;
                    text(&subscription["updatedAt"], 64, true)?;
                    text(&subscription["expiresAt"], 64, true)?;
                }
            }
            text(&value["activeSubscriptionUrl"], 16384, true)?;
            if let Some(active) = value["activeSubscriptionUrl"].as_str() {
                if !urls.contains(active) {
                    return Err(Failure::Invalid);
                }
            }
            if !value["routingPolicy"].is_null() {
                let routing = &value["routingPolicy"];
                object(routing, &["enabled", "direction", "defaultAction", "rules"])?;
                boolean(&routing["enabled"])?;
                choice(&routing["direction"], &["vpn", "direct"])?;
                choice(&routing["defaultAction"], &["vpn", "direct"])?;
                if !routing["rules"].is_null() {
                    let rules = routing["rules"]
                        .as_array()
                        .filter(|v| v.len() <= 2048)
                        .ok_or(Failure::Invalid)?;
                    for rule in rules {
                        object(rule, &["match", "target", "enabled"])?;
                        if rule["match"].is_null() {
                            return Err(Failure::Invalid);
                        }
                        choice(
                            &rule["match"],
                            &["application", "domain", "exactDomain", "ip"],
                        )?;
                        text(&rule["target"], 4096, false)?;
                        if rule["target"].as_str().unwrap().trim().is_empty() {
                            return Err(Failure::Invalid);
                        }
                        boolean(&rule["enabled"])?;
                    }
                }
            }
        }
    }
    bounded(value, 0)?;
    if serde_json::to_vec(value)
        .map_err(|_| Failure::Invalid)?
        .len()
        > MAX_DOCUMENT
    {
        return Err(Failure::Invalid);
    }
    Ok(())
}

fn bounded(value: &Value, depth: usize) -> Result<()> {
    if depth > 24 {
        return Err(Failure::Invalid);
    }
    match value {
        Value::Object(map) => {
            for value in map.values() {
                bounded(value, depth + 1)?;
            }
        }
        Value::Array(array) => {
            for value in array {
                bounded(value, depth + 1)?;
            }
        }
        _ => {}
    }
    Ok(())
}

fn merge(previous: Option<&Value>, incoming: Value) -> Value {
    match (previous, incoming) {
        (Some(Value::Object(old)), Value::Object(new)) => {
            let mut result = old.clone();
            for (key, value) in new {
                result.insert(key.clone(), merge(old.get(&key), value));
            }
            Value::Object(result)
        }
        (Some(Value::Array(old)), Value::Array(new)) => Value::Array(
            new.into_iter()
                .map(|value| {
                    let previous = if value.get("url").is_some() {
                        old.iter().find(|old| old["url"] == value["url"])
                    } else if value.get("match").is_some() {
                        old.iter().find(|old| {
                            old["match"] == value["match"] && old["target"] == value["target"]
                        })
                    } else {
                        None
                    };
                    merge(previous, value)
                })
                .collect(),
        ),
        (_, incoming) => incoming,
    }
}

struct Existing {
    _handle: Option<File>,
    value: Option<Value>,
    revision: String,
}

fn existing(path: &Path, document: Document) -> Result<Existing> {
    let mut file = match OpenOptions::new()
        .read(true)
        .share_mode(FILE_SHARE_READ | FILE_SHARE_DELETE)
        .custom_flags(FILE_FLAG_OPEN_REPARSE_POINT)
        .open(path)
    {
        Ok(file) => file,
        Err(error) if error.kind() == io::ErrorKind::NotFound => {
            return Ok(Existing {
                _handle: None,
                value: None,
                revision: "missing".into(),
            })
        }
        Err(error) => return Err(error.into()),
    };
    let mut info: BY_HANDLE_FILE_INFORMATION = unsafe { zeroed() };
    if unsafe { GetFileInformationByHandle(file.as_raw_handle(), &mut info) } == 0 {
        return Err(io::Error::last_os_error().into());
    }
    if info.dwFileAttributes & (FILE_ATTRIBUTE_REPARSE_POINT | FILE_ATTRIBUTE_DIRECTORY) != 0
        || info.nNumberOfLinks != 1
        || file.metadata()?.len() > MAX_DOCUMENT as u64
    {
        return Err(Failure::Stored);
    }
    let mut bytes = Vec::new();
    (&mut file)
        .take(MAX_DOCUMENT as u64 + 1)
        .read_to_end(&mut bytes)?;
    if bytes.len() > MAX_DOCUMENT {
        return Err(Failure::Stored);
    }
    let value: Value = serde_json::from_slice(&bytes).map_err(|_| Failure::Stored)?;
    if !value.is_object()
        || (matches!(document, Document::App) && value["version"] != 1)
        || bounded(&value, 0).is_err()
    {
        return Err(Failure::Stored);
    }
    Ok(Existing {
        _handle: Some(file),
        value: Some(value),
        revision: format!("{:x}", Sha256::digest(&bytes)),
    })
}

fn directory(root: &Path) -> Result<File> {
    authorization::protected(root)?;
    let path = root.join("settings");
    authorization::protected(&path)?;
    let file = OpenOptions::new()
        .access_mode(FILE_READ_ATTRIBUTES | READ_CONTROL)
        .share_mode(FILE_SHARE_READ | FILE_SHARE_WRITE)
        .custom_flags(FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT)
        .open(path)?;
    let metadata = file.metadata()?;
    if !metadata.is_dir() || metadata.file_attributes() & FILE_ATTRIBUTE_REPARSE_POINT != 0 {
        return Err(io::Error::other("Invalid settings directory type").into());
    }
    Ok(file)
}

fn replace(path: &Path, bytes: &[u8]) -> Result<()> {
    let mut random = [0u8; 16];
    if unsafe {
        BCryptGenRandom(
            null_mut(),
            random.as_mut_ptr(),
            random.len() as u32,
            BCRYPT_USE_SYSTEM_PREFERRED_RNG,
        )
    } < 0
    {
        return Err(io::Error::other("Settings random source failed").into());
    }
    let name = random
        .iter()
        .map(|v| format!("{v:02x}"))
        .collect::<String>();
    let temporary = path.parent().unwrap().join(format!(".settings-{name}.tmp"));
    let descriptor = SecurityDescriptor::new("O:SYG:SYD:P(A;;FA;;;SY)(A;;FA;;;BA)")?;
    let security = SECURITY_ATTRIBUTES {
        nLength: size_of::<SECURITY_ATTRIBUTES>() as u32,
        lpSecurityDescriptor: descriptor.as_ptr(),
        bInheritHandle: 0,
    };
    let handle = unsafe {
        CreateFileW(
            wide(&temporary).as_ptr(),
            GENERIC_WRITE,
            0,
            &security,
            CREATE_NEW,
            FILE_ATTRIBUTE_NORMAL,
            null_mut(),
        )
    };
    let mut output = File::from(unsafe {
        owned(handle).map_err(|e| {
            io::Error::new(
                e.kind(),
                format!("Creating the settings temporary file failed: {e}"),
            )
        })?
    });
    let result = output
        .write_all(bytes)
        .map_err(|e| io::Error::new(e.kind(), format!("Writing settings failed: {e}")))
        .and_then(|_| {
            output
                .sync_all()
                .map_err(|e| io::Error::new(e.kind(), format!("Flushing settings failed: {e}")))
        });
    drop(output);
    let result = result.and_then(|_| {
        if unsafe {
            MoveFileExW(
                wide(&temporary).as_ptr(),
                wide(path).as_ptr(),
                MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH,
            )
        } == 0
        {
            let error = io::Error::last_os_error();
            Err(io::Error::new(
                error.kind(),
                format!("Replacing settings failed: {error}"),
            ))
        } else {
            Ok(())
        }
    });
    if result.is_err() {
        let _ = fs::remove_file(&temporary);
    }
    result.map_err(Into::into)
}

pub(super) struct Store {
    root: PathBuf,
}
impl Store {
    pub fn new(root: PathBuf) -> Self {
        Self { root }
    }
    fn execute(&self, request: Request) -> Result<Value> {
        if request.protocol != 1 {
            return Err(Failure::Invalid);
        }
        let _guard = directory(&self.root)?;
        let path = self.root.join("settings").join(request.document.name());
        let old = existing(&path, request.document)?;
        match request.command.as_str() {
            "settings.read" if request.value.is_none() && request.revision.is_none() => {
                Ok(json!({"protocol":1,"ok":true,"value":old.value,"revision":old.revision}))
            }
            "settings.write" => {
                let incoming = request.value.ok_or(Failure::Invalid)?;
                validate(request.document, &incoming)?;
                if request.revision.as_deref() != Some(old.revision.as_str()) {
                    return Err(Failure::Conflict);
                }
                let value = merge(old.value.as_ref(), incoming);
                bounded(&value, 0)?;
                let bytes = serde_json::to_vec(&value).map_err(|_| Failure::Invalid)?;
                if bytes.len() > MAX_DOCUMENT {
                    return Err(Failure::Invalid);
                }
                drop(old);
                replace(&path, &bytes)?;
                Ok(
                    json!({"protocol":1,"ok":true,"revision":format!("{:x}", Sha256::digest(&bytes))}),
                )
            }
            _ => Err(Failure::Invalid),
        }
    }
    pub fn reply(&self, bytes: &[u8]) -> Vec<u8> {
        let result = serde_json::from_slice::<Request>(bytes)
            .map_err(|_| Failure::Invalid)
            .and_then(|r| self.execute(r));
        let value = result.unwrap_or_else(|failure| {
            let mut reply = json!({"protocol":1,"ok":false,"error":match &failure {
                Failure::Invalid => "invalid_settings", Failure::Stored => "invalid_stored_settings", Failure::Conflict => "settings_conflict", Failure::Storage(_) => "settings_storage_unavailable"
            }});
            if let Failure::Storage(error) = &failure {
                #[cfg(feature = "service-scm-fixture")]
                { reply["diagnostic"] = error.to_string().into(); }
                let _ = error;
            }
            let _ = &mut reply;
            reply
        });
        serde_json::to_vec(&value).unwrap()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn typed_documents_reject_paths_unknown_fields_versions_and_oversized_values() {
        assert!(serde_json::from_value::<Request>(
            json!({"protocol":1,"command":"settings.read","document":"../service-access.json"})
        )
        .is_err());
        assert!(validate(Document::App, &json!({"version":2})).is_err());
        assert!(validate(
            Document::Language,
            &json!({"language":"ru","path":"C:/secret"})
        )
        .is_err());
        assert!(validate(Document::Updates, &json!({"sources":["file:///private"]})).is_err());
        assert!(validate(Document::App, &json!({"version":1,"subscriptions":[{"url":"https://example.org/sub","command":"run"}]})).is_err());
        assert!(validate(Document::App, &json!({"version":1,"subscriptions":[{"url":format!("https://example.org/{}", "x".repeat(20000))}]})).is_err());
        assert!(validate(Document::App, &json!({"version":1,"mode":"proxy","core":"xray","dnsProvider":"quad9","routingPolicy":{"enabled":true,"direction":"direct","rules":[{"match":"application","target":"C:/Program Files/App/app.exe","enabled":true}]}})).is_ok());
    }
    #[test]
    fn writes_preserve_unrecognized_existing_metadata_but_honor_removals() {
        let old = json!({"future":42,"subscriptions":[{"url":"https://one.example/sub","extra":"keep"},{"url":"https://two.example/sub"}],"routingPolicy":{"future":true}});
        let new = json!({"subscriptions":[{"url":"https://one.example/sub","updatedAt":null}],"routingPolicy":{"enabled":false}});
        let result = merge(Some(&old), new);
        assert_eq!(result["future"], 42);
        assert_eq!(result["subscriptions"].as_array().unwrap().len(), 1);
        assert_eq!(result["subscriptions"][0]["extra"], "keep");
        assert_eq!(result["routingPolicy"]["future"], true);
        assert_eq!(result["routingPolicy"]["enabled"], false);
    }
}
