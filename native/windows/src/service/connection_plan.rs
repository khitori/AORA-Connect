// SPDX-License-Identifier: GPL-3.0-or-later
use super::core::Core;
use serde::Deserialize;
use serde_json::{json, Value};
use std::{io, net::IpAddr};

#[derive(Clone, Copy, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub(super) enum Mode {
    Tun,
    Proxy,
}
#[derive(Clone, Copy, Deserialize)]
#[serde(rename_all = "camelCase")]
enum Dns {
    Cloudflare,
    Google,
    Quad9,
}
impl Dns {
    fn address(self) -> &'static str {
        match self {
            Self::Cloudflare => "1.1.1.1",
            Self::Google => "8.8.8.8",
            Self::Quad9 => "9.9.9.9",
        }
    }
    fn server(self, tag: &str, detour: Option<&str>) -> Value {
        let name = match self {
            Self::Cloudflare => "cloudflare-dns.com",
            Self::Google => "dns.google",
            Self::Quad9 => "dns.quad9.net",
        };
        let mut value = json!({"type":"https","tag":tag,"server":self.address(),"path":"/dns-query","tls":{"enabled":true,"server_name":name}});
        if let Some(detour) = detour {
            value["detour"] = detour.into();
        }
        value
    }
}
#[derive(Clone, Copy, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
enum Direction {
    Vpn,
    Direct,
}
impl Direction {
    fn tag(self) -> &'static str {
        if self == Self::Vpn {
            "proxy"
        } else {
            "direct"
        }
    }
}
#[derive(Clone, Copy, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
enum Match {
    Application,
    Domain,
    ExactDomain,
    Ip,
}
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Rule {
    r#match: Match,
    target: String,
    enabled: bool,
}
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Routing {
    enabled: bool,
    direction: Direction,
    rules: Vec<Rule>,
}
#[derive(Deserialize)]
#[serde(deny_unknown_fields, rename_all = "camelCase")]
pub(super) struct Plan {
    pub core: Core,
    mode: Mode,
    dns: Dns,
    leak_protection: bool,
    routing: Routing,
    outbound: Value,
}

fn invalid() -> io::Error {
    io::Error::other("Invalid or unsupported connection plan")
}
fn require(valid: bool) -> io::Result<()> {
    if valid {
        Ok(())
    } else {
        Err(invalid())
    }
}
fn fields(value: &Value, allowed: &[&str]) -> io::Result<()> {
    let map = value.as_object().ok_or_else(invalid)?;
    require(map.keys().all(|key| allowed.contains(&key.as_str())))
}
fn text(value: &Value, empty: bool) -> io::Result<&str> {
    let text = value.as_str().ok_or_else(invalid)?;
    require(
        (empty || !text.is_empty()) && text.len() <= 16384 && !text.chars().any(char::is_control),
    )?;
    Ok(text)
}
fn optional_text(value: &Value) -> io::Result<()> {
    if !value.is_null() {
        text(value, true)?;
    }
    Ok(())
}
fn strings(value: &Value) -> io::Result<()> {
    let list = value.as_array().ok_or_else(invalid)?;
    require(!list.is_empty() && list.len() <= 64)?;
    for item in list {
        text(item, false)?;
    }
    Ok(())
}
fn uuid(value: &Value) -> io::Result<()> {
    let id = text(value, false)?;
    require(
        id.len() == 36
            && id.bytes().enumerate().all(|(i, b)| {
                if [8, 13, 18, 23].contains(&i) {
                    b == b'-'
                } else {
                    b.is_ascii_hexdigit()
                }
            }),
    )
}
fn endpoint(value: &Value, address: &str, port: &str) -> io::Result<()> {
    require(text(&value[address], false)?.parse::<IpAddr>().is_ok())?;
    require(
        value[port]
            .as_u64()
            .is_some_and(|v| (1..=65535).contains(&v)),
    )
}
fn tls(value: &Value) -> io::Result<()> {
    fields(
        value,
        &[
            "enabled",
            "server_name",
            "insecure",
            "alpn",
            "utls",
            "reality",
        ],
    )?;
    require(value["enabled"] == true)?;
    text(&value["server_name"], true)?;
    require(value["insecure"].is_boolean())?;
    if !value["alpn"].is_null() {
        strings(&value["alpn"])?;
    }
    if !value["utls"].is_null() {
        fields(&value["utls"], &["enabled", "fingerprint"])?;
        require(value["utls"]["enabled"] == true)?;
        text(&value["utls"]["fingerprint"], false)?;
    }
    if !value["reality"].is_null() {
        let reality = &value["reality"];
        fields(reality, &["enabled", "public_key", "short_id"])?;
        require(reality["enabled"] == true)?;
        text(&reality["public_key"], false)?;
        text(&reality["short_id"], true)?;
    }
    Ok(())
}
fn transport(value: &Value) -> io::Result<()> {
    let kind = value["type"].as_str().ok_or_else(invalid)?;
    match kind {
        "ws" => {
            fields(value, &["type", "path", "headers"])?;
            if !value["headers"].is_null() {
                fields(&value["headers"], &["Host"])?;
                text(&value["headers"]["Host"], false)?;
            }
        }
        "grpc" => {
            fields(value, &["type", "service_name"])?;
            text(&value["service_name"], true)?;
        }
        "httpupgrade" => {
            fields(value, &["type", "path", "host"])?;
            optional_text(&value["host"])?;
        }
        "http" => {
            fields(value, &["type", "path", "host"])?;
            if !value["host"].is_null() {
                strings(&value["host"])?;
            }
        }
        _ => return Err(invalid()),
    }
    optional_text(&value["path"])
}
pub(super) fn outbound(core: Core, value: &Value) -> io::Result<()> {
    require(value["tag"] == "proxy")?;
    if core == Core::Xray {
        fields(value, &["protocol", "tag", "settings", "streamSettings"])?;
        require(value["protocol"] == "vless")?;
        let settings = &value["settings"];
        fields(settings, &["address", "port", "id", "encryption"])?;
        endpoint(settings, "address", "port")?;
        uuid(&settings["id"])?;
        require(settings["encryption"] == "none")?;
        let stream = &value["streamSettings"];
        fields(
            stream,
            &["method", "security", "tlsSettings", "grpcSettings"],
        )?;
        require(stream["method"] == "grpc" && stream["security"] == "tls")?;
        let tls = &stream["tlsSettings"];
        fields(
            tls,
            &[
                "serverName",
                "allowInsecure",
                "pinnedPeerCertSha256",
                "fingerprint",
                "alpn",
            ],
        )?;
        text(&tls["serverName"], true)?;
        require(tls["allowInsecure"] == false)?;
        let pins = text(&tls["pinnedPeerCertSha256"], false)?;
        require(
            pins.split(',')
                .all(|pin| pin.len() == 64 && pin.bytes().all(|b| b.is_ascii_hexdigit())),
        )?;
        optional_text(&tls["fingerprint"])?;
        if !tls["alpn"].is_null() {
            strings(&tls["alpn"])?;
        }
        fields(&stream["grpcSettings"], &["serviceName", "multiMode"])?;
        text(&stream["grpcSettings"]["serviceName"], true)?;
        return require(stream["grpcSettings"]["multiMode"] == false);
    }
    let kind = value["type"].as_str().ok_or_else(invalid)?;
    let common = ["type", "tag", "server", "server_port"];
    let specific: &[&str] = match kind {
        "hysteria2" => &["password", "tls", "obfs"],
        "vless" => &["uuid", "flow", "tls", "transport"],
        "trojan" => &["password", "tls", "transport"],
        "shadowsocks" => &["method", "password"],
        "vmess" => &["uuid", "security", "alter_id", "tls", "transport"],
        _ => return Err(invalid()),
    };
    fields(
        value,
        &common.iter().chain(specific).copied().collect::<Vec<_>>(),
    )?;
    endpoint(value, "server", "server_port")?;
    if matches!(kind, "hysteria2" | "trojan" | "shadowsocks") {
        text(&value["password"], kind == "hysteria2")?;
    }
    if matches!(kind, "vless" | "vmess") {
        uuid(&value["uuid"])?;
    }
    if !value["tls"].is_null() {
        tls(&value["tls"])?;
    }
    if matches!(kind, "hysteria2" | "trojan") {
        require(value["tls"].is_object())?;
    }
    if !value["transport"].is_null() {
        transport(&value["transport"])?;
    }
    if !value["flow"].is_null() {
        require(value["flow"] == "xtls-rprx-vision" && value["tls"].is_object())?;
    }
    if !value["obfs"].is_null() {
        fields(&value["obfs"], &["type", "password"])?;
        require(matches!(
            value["obfs"]["type"].as_str(),
            Some("salamander" | "gecko")
        ))?;
        text(&value["obfs"]["password"], false)?;
    }
    if kind == "shadowsocks" {
        require(matches!(
            value["method"].as_str(),
            Some(
                "2022-blake3-aes-128-gcm"
                    | "2022-blake3-aes-256-gcm"
                    | "2022-blake3-chacha20-poly1305"
                    | "none"
                    | "aes-128-gcm"
                    | "aes-192-gcm"
                    | "aes-256-gcm"
                    | "chacha20-ietf-poly1305"
                    | "xchacha20-ietf-poly1305"
                    | "aes-128-ctr"
                    | "aes-192-ctr"
                    | "aes-256-ctr"
                    | "aes-128-cfb"
                    | "aes-192-cfb"
                    | "aes-256-cfb"
                    | "rc4-md5"
                    | "chacha20-ietf"
                    | "xchacha20"
            )
        ))?;
    }
    if kind == "vmess" {
        require(matches!(
            value["security"].as_str(),
            Some("auto" | "none" | "zero" | "aes-128-gcm" | "chacha20-poly1305" | "aes-128-ctr")
        ))?;
        require(
            value["alter_id"]
                .as_u64()
                .is_some_and(|v| v <= u32::MAX as u64),
        )?;
    }
    Ok(())
}

impl Rule {
    fn validate(&self) -> io::Result<()> {
        let target = self.target.as_str();
        require(
            !target.trim().is_empty()
                && target.len() <= 4096
                && !target.chars().any(char::is_control),
        )?;
        match self.r#match {
            Match::Application => {
                require(!target.ends_with(['/', '\\']) && !target.contains(['*', '?']))
            }
            Match::Domain | Match::ExactDomain => require(
                target.len() <= 253
                    && target
                        .bytes()
                        .next()
                        .is_some_and(|b| b.is_ascii_alphanumeric())
                    && target
                        .bytes()
                        .all(|b| b.is_ascii_alphanumeric() || b == b'.' || b == b'-')
                    && !target.contains(".."),
            ),
            Match::Ip => {
                let mut parts = target.split('/');
                let ip: IpAddr = parts.next().unwrap().parse().map_err(|_| invalid())?;
                if let Some(prefix) = parts.next() {
                    require(
                        prefix
                            .parse::<u8>()
                            .is_ok_and(|p| p <= if ip.is_ipv4() { 32 } else { 128 }),
                    )?;
                }
                require(parts.next().is_none())
            }
        }
    }
}
impl Plan {
    pub fn build(&self) -> io::Result<Value> {
        outbound(self.core, &self.outbound)?;
        require(self.routing.rules.len() <= 2048)?;
        for rule in &self.routing.rules {
            rule.validate()?;
        }
        let tun = self.mode == Mode::Tun;
        let mut config = if self.core == Core::SingBox {
            json!({"log":{"level":"info","timestamp":true},
                "dns":{"servers":[{"type":"local","tag":"local-dns"}],"final":if tun{"vpn-dns"}else{"local-dns"}},
                "inbounds":[if tun {json!({"type":"tun","tag":"vpn-tun","interface_name":"AORA VPN","address":["172.29.0.1/30","fdfe:dcba:9876::1/126"],"mtu":1500,"auto_route":true,"strict_route":self.leak_protection,"dns_mode":"hijack","stack":"mixed"})} else {json!({"type":"mixed","tag":"local-proxy","listen":"127.0.0.1","listen_port":17890})}],
                "outbounds":[self.outbound],"route":{"final":"proxy","default_domain_resolver":"local-dns","auto_detect_interface":true}})
        } else {
            let mut inbound = if tun {
                json!({"tag":"vpn-tun","protocol":"tun","settings":{"name":"AORA VPN","desc":"AORA VPN","mtu":1500,"gateway":["172.29.0.1/30","fdfe:dcba:9876::1/126"],"dns":[self.dns.address()],"autoSystemRoutingTable":["0.0.0.0/0","::/0"],"autoOutboundsInterface":"auto"}})
            } else {
                json!({"tag":"local-proxy","listen":"127.0.0.1","port":17890,"protocol":"http"})
            };
            if tun && self.leak_protection {
                inbound["settings"]["autoSystemWfpBlockLeak"] = json!(["dns", "misconfigtun"]);
            }
            json!({"log":{"loglevel":"warning"},"inbounds":[inbound],"outbounds":[self.outbound],"routing":{"domainStrategy":"IPIfNonMatch"}})
        };
        if self.core == Core::SingBox && tun {
            config["dns"]["servers"]
                .as_array_mut()
                .unwrap()
                .push(self.dns.server("vpn-dns", Some("proxy")));
            config["route"]["rules"] =
                json!([{"action":"sniff"},{"protocol":"dns","action":"hijack-dns"}]);
        }
        let active: Vec<_> = self.routing.rules.iter().filter(|r| r.enabled).collect();
        if self.routing.enabled && !active.is_empty() {
            let direction = self.routing.direction;
            let default = if direction == Direction::Direct {
                Direction::Vpn
            } else {
                Direction::Direct
            };
            let outbounds = config["outbounds"].as_array_mut().unwrap();
            outbounds.push(if self.core == Core::SingBox {
                json!({"type":"direct","tag":"direct"})
            } else {
                json!({"protocol":"freedom","tag":"direct"})
            });
            if self.core == Core::SingBox {
                for (tag, detour) in [("direct-dns", None), ("vpn-dns", Some("proxy"))] {
                    let servers = config["dns"]["servers"].as_array_mut().unwrap();
                    if !servers.iter().any(|s| s["tag"] == tag) {
                        servers.push(self.dns.server(tag, detour));
                    }
                }
                config["dns"]["final"] = if default == Direction::Direct {
                    "direct-dns"
                } else {
                    "vpn-dns"
                }
                .into();
                if config["route"]["rules"].is_null() {
                    config["route"]["rules"] = json!([]);
                }
                config["dns"]["rules"] = json!([]);
                for rule in active {
                    let path = rule.target.contains(['/', '\\']);
                    let field = match rule.r#match {
                        Match::Application => {
                            if path {
                                "process_path"
                            } else {
                                "process_name"
                            }
                        }
                        Match::Domain => "domain_suffix",
                        Match::ExactDomain => "domain",
                        Match::Ip => "ip_cidr",
                    };
                    let target = if rule.r#match == Match::Ip && !rule.target.contains('/') {
                        format!(
                            "{}/{}",
                            rule.target,
                            if rule.target.parse::<IpAddr>().unwrap().is_ipv4() {
                                32
                            } else {
                                128
                            }
                        )
                    } else if rule.r#match == Match::Application && path {
                        rule.target.replace('/', "\\")
                    } else {
                        rule.target.clone()
                    };
                    let mut route = json!({"action":"route","outbound":direction.tag()});
                    route[field] = json!([target]);
                    config["route"]["rules"]
                        .as_array_mut()
                        .unwrap()
                        .push(route.clone());
                    if rule.r#match != Match::Ip {
                        route.as_object_mut().unwrap().remove("outbound");
                        route["server"] = if direction == Direction::Vpn {
                            "vpn-dns"
                        } else {
                            "direct-dns"
                        }
                        .into();
                        config["dns"]["rules"].as_array_mut().unwrap().push(route);
                    }
                }
                config["route"]["final"] = default.tag().into();
            } else {
                config["inbounds"][0]["sniffing"] =
                    json!({"enabled":true,"destOverride":["http","tls","quic"],"routeOnly":true});
                let mut rules = Vec::new();
                for rule in active {
                    let field = match rule.r#match {
                        Match::Application => "process",
                        Match::Domain | Match::ExactDomain => "domain",
                        Match::Ip => "ip",
                    };
                    let target = match rule.r#match {
                        Match::Domain => format!("domain:{}", rule.target),
                        Match::ExactDomain => format!("full:{}", rule.target),
                        Match::Application => {
                            if rule.target.contains(['/', '\\']) {
                                rule.target.replace('\\', "/")
                            } else {
                                rule.target
                                    .strip_suffix(".exe")
                                    .or_else(|| {
                                        if rule.target.to_ascii_lowercase().ends_with(".exe") {
                                            Some(&rule.target[..rule.target.len() - 4])
                                        } else {
                                            None
                                        }
                                    })
                                    .unwrap_or(&rule.target)
                                    .to_owned()
                            }
                        }
                        Match::Ip => rule.target.clone(),
                    };
                    let mut route = json!({"type":"field","outboundTag":direction.tag()});
                    route[field] = json!([target]);
                    rules.push(route);
                }
                rules.push(json!({"type":"field","network":"tcp,udp","outboundTag":default.tag()}));
                config["routing"]["rules"] = rules.into();
            }
        }
        require(serde_json::to_vec(&config)?.len() <= 1024 * 1024)?;
        Ok(config)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn base() -> Value {
        json!({"core":"singBox","mode":"proxy","dns":"cloudflare","leakProtection":true,"routing":{"enabled":true,"direction":"direct","rules":[]},"outbound":{"type":"hysteria2","tag":"proxy","server":"127.0.0.1","server_port":443,"password":"dummy","tls":{"enabled":true,"server_name":"example.com","insecure":false}}})
    }
    #[test]
    fn plans_reject_raw_configuration_paths_hooks_and_unbounded_fields() {
        let valid = base();
        assert!(serde_json::from_value::<Plan>(valid.clone())
            .unwrap()
            .build()
            .is_ok());
        let mut empty_auth = valid.clone();
        empty_auth["outbound"]["password"] = json!("");
        empty_auth["outbound"]["tls"]["server_name"] = json!("");
        assert!(serde_json::from_value::<Plan>(empty_auth)
            .unwrap()
            .build()
            .is_ok());
        for field in [
            "config",
            "inbounds",
            "log",
            "path",
            "executable",
            "user_sid",
        ] {
            let mut invalid = valid.clone();
            invalid[field] = json!("C:/secret");
            assert!(serde_json::from_value::<Plan>(invalid).is_err());
        }
        for (path, value) in [
            ("/outbound/tls/certificate_path", json!("C:/secret")),
            ("/outbound/tls/client_key", json!("C:/secret")),
            ("/outbound/tls/enabled", json!(false)),
            ("/outbound/server", json!("server.example")),
            ("/outbound/server_port", json!(0)),
            ("/outbound/type", json!("direct")),
            ("/outbound/password", json!("x".repeat(16385))),
            (
                "/routing/rules",
                json!([{"match":"domain","target":"*.example.com","enabled":true}]),
            ),
            (
                "/routing/rules",
                json!([{"match":"ip","target":"192.0.2.2/33","enabled":true}]),
            ),
            (
                "/routing/rules",
                json!([{"match":"application","target":"cmd.exe\nrun","enabled":true}]),
            ),
        ] {
            let mut bad = valid.clone();
            let mut parts = path[1..].split('/').collect::<Vec<_>>();
            let key = parts.pop().unwrap();
            let mut parent = &mut bad;
            for part in parts {
                parent = &mut parent[part];
            }
            parent[key] = value;
            assert!(
                serde_json::from_value::<Plan>(bad)
                    .unwrap()
                    .build()
                    .is_err(),
                "{path}"
            );
        }
    }
    #[test]
    fn client_generated_configuration_parity() {
        let Some(path) = std::env::var_os("AORA_TEST_PLAN_PARITY") else {
            return;
        };
        let cases: Value = serde_json::from_slice(&std::fs::read(path).unwrap()).unwrap();
        let cases = cases.as_array().unwrap();
        assert!(cases.len() >= 700);
        for (index, case) in cases.iter().enumerate() {
            let plan: Plan = serde_json::from_value(case["plan"].clone()).unwrap();
            assert_eq!(
                plan.build().unwrap(),
                case["expected"],
                "parity case {index}"
            );
        }
        println!("Verified {} generated connection plans", cases.len());
    }
}
