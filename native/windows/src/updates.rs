// SPDX-License-Identifier: GPL-3.0-or-later
use base64::{engine::general_purpose::STANDARD, Engine};
use ed25519_dalek::{Signature, VerifyingKey};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::{
    fs::File,
    io::{Read, Seek, SeekFrom},
    path::Path,
};

pub type Result<T> = std::result::Result<T, Box<dyn std::error::Error>>;
pub const MAX_INSTALLER_SIZE: u64 = 512 * 1024 * 1024;
const FOOTER_SIZE: u64 = 24;

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Envelope {
    signed: String,
    signature: String,
}

#[derive(Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Release {
    pub app_id: String,
    pub platform: String,
    pub version: String,
    pub size: u64,
    pub sha256: String,
    pub urls: Vec<String>,
    pub notes: String,
}

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}
fn decode_hex(value: &str) -> Result<Vec<u8>> {
    if value.len() % 2 != 0 {
        return Err("Invalid key encoding".into());
    }
    (0..value.len())
        .step_by(2)
        .map(|i| Ok(u8::from_str_radix(&value[i..i + 2], 16)?))
        .collect()
}

pub fn version(value: &str) -> Result<[u32; 4]> {
    let (name, build) = value
        .split_once('+')
        .ok_or("Release version must include a build number")?;
    let parts: Vec<_> = name.split('.').collect();
    if parts.len() != 3 {
        return Err("Invalid release version".into());
    }
    Ok([
        parts[0].parse()?,
        parts[1].parse()?,
        parts[2].parse()?,
        build.parse()?,
    ])
}

pub fn verify_manifest_with_key(bytes: &[u8], key: &[u8; 32]) -> Result<Release> {
    if bytes.len() > 65536 {
        return Err("Release metadata is too large".into());
    }
    let envelope: Envelope = serde_json::from_slice(bytes)?;
    let signed = STANDARD.decode(envelope.signed)?;
    let signature = Signature::from_slice(&STANDARD.decode(envelope.signature)?)?;
    VerifyingKey::from_bytes(key)?
        .verify_strict(&signed, &signature)
        .map_err(|_| "Update signature did not verify")?;
    let release: Release = serde_json::from_slice(&signed)?;
    if release.app_id != "AORAConnect" || release.platform != "windows-x64" {
        return Err("Update is for a different application or platform".into());
    }
    version(&release.version)?;
    if release.size == 0
        || release.size > MAX_INSTALLER_SIZE
        || release.sha256.len() != 64
        || !release.sha256.chars().all(|c| c.is_ascii_hexdigit())
        || release.urls.is_empty()
    {
        return Err("Invalid release metadata".into());
    }
    Ok(release)
}

pub fn verify_manifest(bytes: &[u8]) -> Result<Release> {
    let key: [u8; 32] = decode_hex(env!("AORA_UPDATE_PUBLIC_KEY"))?
        .try_into()
        .map_err(|_| "Invalid trusted release key")?;
    verify_manifest_with_key(bytes, &key)
}

pub fn verify_package(path: &Path) -> Result<Release> {
    let mut file = File::open(path)?;
    let length = file.metadata()?.len();
    if !(FOOTER_SIZE..=MAX_INSTALLER_SIZE + 65536 + FOOTER_SIZE).contains(&length) {
        return Err("Invalid update package size".into());
    }
    file.seek(SeekFrom::End(-(FOOTER_SIZE as i64)))?;
    let mut footer = [0u8; 24];
    file.read_exact(&mut footer)?;
    if &footer[..8] != b"AORAUPD1" {
        return Err("This EXE is not an AORA signed update package".into());
    }
    let payload_size = u64::from_le_bytes(footer[8..16].try_into()?);
    let metadata_size = u64::from_le_bytes(footer[16..24].try_into()?);
    if metadata_size > 65536
        || payload_size > MAX_INSTALLER_SIZE
        || payload_size
            .checked_add(metadata_size)
            .and_then(|v| v.checked_add(FOOTER_SIZE))
            != Some(length)
    {
        return Err("Invalid update package layout".into());
    }
    file.seek(SeekFrom::Start(payload_size))?;
    let mut metadata = vec![0; metadata_size as usize];
    file.read_exact(&mut metadata)?;
    let release = verify_manifest(&metadata)?;
    if release.size != payload_size {
        return Err("Update payload size does not match its signature".into());
    }
    file.seek(SeekFrom::Start(0))?;
    let mut hasher = Sha256::new();
    let mut remaining = payload_size;
    let mut buffer = [0u8; 65536];
    while remaining > 0 {
        let count = std::cmp::min(remaining, buffer.len() as u64) as usize;
        file.read_exact(&mut buffer[..count])?;
        hasher.update(&buffer[..count]);
        remaining -= count as u64;
    }
    if hex(&hasher.finalize()) != release.sha256.to_lowercase() {
        return Err("Update file is damaged or has been modified".into());
    }
    Ok(release)
}

#[cfg(test)]
mod tests {
    use super::*;
    use ed25519_dalek::{Signer, SigningKey};
    #[test]
    fn signed_metadata_rejects_tampering_and_other_keys() {
        let key = SigningKey::from_bytes(&[7; 32]);
        let signed = br#"{"appId":"AORAConnect","platform":"windows-x64","version":"1.2.3+4","size":123,"sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","urls":["https://example.com/setup.exe"],"notes":""}"#;
        let envelope = serde_json::json!({"signed": STANDARD.encode(signed), "signature": STANDARD.encode(key.sign(signed).to_bytes())});
        let encoded = serde_json::to_vec(&envelope).unwrap();
        assert_eq!(
            verify_manifest_with_key(&encoded, &key.verifying_key().to_bytes())
                .unwrap()
                .version,
            "1.2.3+4"
        );
        assert!(verify_manifest_with_key(
            &encoded,
            &SigningKey::from_bytes(&[8; 32]).verifying_key().to_bytes()
        )
        .is_err());
        let mut changed = envelope;
        changed["signed"] = serde_json::Value::String(STANDARD.encode(b"changed"));
        assert!(verify_manifest_with_key(
            &serde_json::to_vec(&changed).unwrap(),
            &key.verifying_key().to_bytes()
        )
        .is_err());
    }
    #[test]
    fn release_order_includes_build_number() {
        assert!(version("1.0.0+2").unwrap() > version("1.0.0+1").unwrap());
        assert!(version("1.1.0+1").unwrap() > version("1.0.0+99").unwrap());
        assert!(version("1.0.0").is_err());
    }
}
