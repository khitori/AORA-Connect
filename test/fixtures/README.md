The connection probe PEM files are intentionally public test credentials for a
local, self-signed TLS server. `connection_probe_test.dart` uses them to verify
certificate rejection and endpoint fallback. The application does not load them.
