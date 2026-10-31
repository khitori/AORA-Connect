// SPDX-License-Identifier: GPL-3.0-or-later
use std::{env, fs, path::PathBuf};

fn main() {
    println!("cargo:rerun-if-env-changed=AORA_MIGRATION_FIXTURE_ROOT");
    if env::var_os("CARGO_FEATURE_MIGRATION_FIXTURE").is_some() {
        let root = env::var("AORA_MIGRATION_FIXTURE_ROOT").expect("Migration fixtures require an isolated root");
        println!("cargo:rustc-env=AORA_MIGRATION_FIXTURE_ROOT={root}");
    }
    println!("cargo:rerun-if-changed=../../release/update-public-key.txt");
    println!("cargo:rerun-if-changed=../../pubspec.yaml");
    let update_key = fs::read_to_string("../../release/update-public-key.txt")
        .expect("Missing public release key; run tool/sign_release.dart init first");
    let update_key = update_key.trim();
    assert!(
        update_key.len() == 64 && update_key.chars().all(|c| c.is_ascii_hexdigit()),
        "Invalid release public key"
    );
    println!("cargo:rustc-env=AORA_UPDATE_PUBLIC_KEY={update_key}");
    let pubspec = fs::read_to_string("../../pubspec.yaml").unwrap();
    let version = pubspec
        .lines()
        .find_map(|line| line.strip_prefix("version:"))
        .unwrap()
        .trim();
    println!("cargo:rustc-env=AORA_APP_VERSION={version}");
    println!("cargo:rerun-if-env-changed=AORA_FLUTTER_HEADER");
    println!("cargo:rerun-if-env-changed=AORA_PLUGIN_REGISTRANT");
    println!("cargo:rerun-if-env-changed=AORA_RESOURCE_COMPILER");
    if env::var_os("CARGO_FEATURE_PORTABLE").is_some() {
        println!("cargo:rerun-if-changed=portable.rc");
        println!("cargo:rerun-if-changed=../../windows/runner/resources/app_icon.ico");
        let resource = PathBuf::from(env::var_os("OUT_DIR").unwrap()).join("portable.res");
        let compiler = env::var_os("AORA_RESOURCE_COMPILER").unwrap_or_else(|| "rc.exe".into());
        let status = std::process::Command::new(compiler)
            .arg("/nologo")
            .arg("/fo")
            .arg(&resource)
            .arg("portable.rc")
            .status()
            .expect("Run Windows SDK resource compiler for launcher icon");
        assert!(status.success(), "Compile launcher icon resource");
        println!(
            "cargo:rustc-link-arg-bin=AORAConnect={}",
            resource.display()
        );
    }
    if env::var_os("CARGO_FEATURE_RUNNER").is_none() {
        return;
    }
    let header = env::var_os("AORA_FLUTTER_HEADER")
        .expect("The runner feature must be built by Flutter's CMake integration");
    let plugins = env::var_os("AORA_PLUGIN_REGISTRANT")
        .expect("Missing generated Flutter plugin registrant path");
    println!(
        "cargo:rerun-if-changed={}",
        PathBuf::from(&header).display()
    );
    println!(
        "cargo:rerun-if-changed={}",
        PathBuf::from(&plugins).display()
    );
    let header = fs::read_to_string(header).expect("Read Flutter Windows API header");
    let end = header
        .find("} FlutterDesktopEngineProperties;")
        .expect("Missing engine properties");
    let start = header[..end]
        .rfind("typedef struct {")
        .expect("Missing properties declaration");
    let mut output = String::from("#[repr(C)]\npub struct EngineProperties {\n");
    for line in header[start..end].lines().map(str::trim) {
        if line.is_empty() || line.starts_with("//") || line == "typedef struct {" {
            continue;
        }
        let line = line
            .strip_suffix(';')
            .expect("Unsupported Flutter properties declaration");
        let (kind, name) = line
            .rsplit_once(' ')
            .expect("Missing properties field name");
        assert!(name.chars().all(|c| c.is_ascii_alphanumeric() || c == '_'));
        let rust = match kind.trim() {
            "const wchar_t*" => "*const u16",
            "const char*" => "*const std::ffi::c_char",
            "const char**" => "*const *const std::ffi::c_char",
            "int" => "i32",
            "bool" => "bool",
            "FlutterDesktopGpuPreference"
            | "FlutterDesktopUIThreadPolicy"
            | "FlutterDesktopAccessibilityMode"
            | "FlutterDesktopImpellerSwitch" => "i32",
            other => panic!(
                "Unsupported Flutter properties field type: {other}; review the Rust ABI bindings"
            ),
        };
        output.push_str(&format!("    pub {name}: {rust},\n"));
    }
    output.push_str("}\n");
    let registrant = fs::read_to_string(plugins).expect("Read generated plugin registrant");
    let mut calls = String::new();
    let mut remaining = registrant.as_str();
    while let Some((before, after)) = remaining.split_once("RegisterWithRegistrar(") {
        let prefix: String = before
            .chars()
            .rev()
            .take_while(|c| c.is_ascii_alphanumeric() || *c == '_')
            .collect::<String>()
            .chars()
            .rev()
            .collect();
        assert!(!prefix.is_empty(), "Unknown plugin registration function");
        let function = format!("{prefix}RegisterWithRegistrar");
        let after_name = after
            .split_once("GetRegistrarForPlugin(\"")
            .expect("Unknown generated plugin registration format")
            .1;
        let (name, tail) = after_name.split_once('"').expect("Missing plugin name");
        assert!(name.chars().all(|c| c.is_ascii_alphanumeric() || c == '_'));
        output.push_str(&format!(
            "extern \"C\" {{ fn {function}(registrar: *mut std::ffi::c_void); }}\n"
        ));
        calls.push_str(&format!("    {function}(FlutterDesktopEngineGetPluginRegistrar(engine, b\"{name}\\0\".as_ptr().cast()));\n"));
        remaining = tail;
    }
    output.push_str("unsafe fn register_plugins(engine: *mut std::ffi::c_void) {\n");
    output.push_str(&calls);
    output.push_str("}\n");
    let path = PathBuf::from(env::var_os("OUT_DIR").unwrap()).join("flutter_generated.rs");
    fs::write(path, output).expect("Write generated Rust Flutter bindings");
}
