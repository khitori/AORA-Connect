// SPDX-License-Identifier: GPL-3.0-or-later
package mobile

import (
	"encoding/base64"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"os"
	"sync"
	"testing"
)

type testPlatform struct{ reject bool }

func (p *testPlatform) Protect(fd int32) error {
	if p.reject {
		return errors.New("protection denied")
	}
	return nil
}

func TestControlledGrpcGatewayConcurrency(t *testing.T) {
	path := os.Getenv("AORA_NATIVE_GATEWAY")
	if path == "" {
		t.Skip("optional controlled gateway")
	}
	encoded, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var definitions map[string]string
	if err := json.Unmarshal(encoded, &definitions); err != nil {
		t.Fatal(err)
	}
	config, err := base64.StdEncoding.DecodeString(definitions["AORA_SMOKE_XRAY_CONFIG"])
	if err != nil {
		t.Fatal(err)
	}
	var root struct {
		Outbounds []json.RawMessage `json:"outbounds"`
	}
	if err := json.Unmarshal(config, &root); err != nil {
		t.Fatal(err)
	}
	var nodes []json.RawMessage
	for i := 0; i < 8; i++ {
		nodes = append(nodes, root.Outbounds[0])
	}
	payload, _ := json.Marshal(nodes)
	Configure(&testPlatform{})
	batch, err := OpenXrayBatch(string(payload))
	if err != nil {
		t.Fatal(err)
	}
	defer batch.Close()
	var wait sync.WaitGroup
	for i := 0; i < len(nodes); i++ {
		for _, method := range []string{"GET", "HEAD"} {
			wait.Add(1)
			go func(index int, method string) {
				defer wait.Done()
				if _, err := batch.Check(int32(index), method, "http://198.18.0.2:18080/"); err != nil {
					t.Errorf("%d %s: %v", index, method, err)
				}
			}(i, method)
		}
	}
	wait.Wait()
}
func (p *testPlatform) Resolve(host string) (string, error) { return "127.0.0.1", nil }
func (p *testPlatform) FindProcess(_, _ string, _ int32, _ string, _ int32) (string, error) {
	return "", nil
}

func TestBatchesDoNotOwnVPNLifetime(t *testing.T) {
	Configure(&testPlatform{})
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Close {
			t.Error("check requested premature Connection: close")
		}
		w.WriteHeader(204)
	}))
	defer server.Close()
	first, err := OpenXrayBatch(`[{"protocol":"freedom"}]`)
	if err != nil {
		t.Fatal(err)
	}
	second, err := OpenXrayBatch(`[{"protocol":"freedom"}]`)
	if err != nil {
		t.Fatal(err)
	}
	defer second.Close()
	for _, method := range []string{"GET", "HEAD"} {
		if _, err := first.Check(0, method, server.URL); err != nil {
			t.Fatal(err)
		}
	}
	first.Close()
	if _, err := first.Check(0, "GET", server.URL); err == nil {
		t.Fatal("closed batch succeeded")
	}
	if _, err := second.Check(0, "HEAD", server.URL); err != nil {
		t.Fatal(err)
	}
	// Simulate a service-owned instance: removing its test handlers must not close it.
	vpn = true
	owned := instance
	second.Close()
	if instance != owned || !instance.IsRunning() {
		t.Fatal("ping cleanup closed the VPN")
	}
	StopXray()
	if instance != nil {
		t.Fatal("explicit VPN stop did not close it")
	}
}

func TestProtectionFailureHasNoDirectFallback(t *testing.T) {
	Configure(&testPlatform{reject: true})
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { t.Error("unprotected request reached server") }))
	defer server.Close()
	batch, err := OpenXrayBatch(`[{"protocol":"freedom"}]`)
	if err != nil {
		t.Fatal(err)
	}
	defer batch.Close()
	if _, err := batch.Check(0, "GET", server.URL); err == nil {
		t.Fatal("unprotected dial succeeded")
	}
}

func TestValidationDoesNotReplaceRunningInstance(t *testing.T) {
	Configure(&testPlatform{})
	batch, err := OpenXrayBatch(`[{"protocol":"freedom"}]`)
	if err != nil {
		t.Fatal(err)
	}
	defer batch.Close()
	owned := instance
	if err := ValidateXray(`{"outbounds":[{"protocol":"freedom"}]}`); err != nil {
		t.Fatal(err)
	}
	if instance != owned {
		t.Fatal("validation replaced the instance")
	}
	if err := ValidateXray(`{"outbounds":[{"protocol":"not-supported"}]}`); err == nil {
		t.Fatal("invalid config accepted")
	}
}

func TestMalformedNodeDoesNotDiscardHealthyNodes(t *testing.T) {
	Configure(&testPlatform{})
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(204) }))
	defer server.Close()
	batch, err := OpenXrayBatch(`[{"protocol":"not-supported"},{"protocol":"freedom"}]`)
	if err != nil {
		t.Fatal(err)
	}
	defer batch.Close()
	if batch.NodeError(0) == "" || batch.NodeError(1) != "" {
		t.Fatal("incorrect per-node errors")
	}
	if _, err := batch.Check(0, "GET", server.URL); err == nil {
		t.Fatal("invalid node succeeded")
	}
	if _, err := batch.Check(1, "HEAD", server.URL); err != nil {
		t.Fatal(err)
	}
}
