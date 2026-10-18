// SPDX-License-Identifier: GPL-3.0-or-later
package mobile

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	_ "github.com/sagernet/sing-box/experimental/libbox"
	"net"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	xnet "github.com/xtls/xray-core/common/net"
	"github.com/xtls/xray-core/common/session"
	"github.com/xtls/xray-core/core"
	"github.com/xtls/xray-core/features/outbound"
	"github.com/xtls/xray-core/infra/conf"
	"github.com/xtls/xray-core/infra/conf/serial"
	_ "github.com/xtls/xray-core/main/distro/all"
	"github.com/xtls/xray-core/transport/internet"
	xgrpc "github.com/xtls/xray-core/transport/internet/grpc"
)

// Platform sockets must use a physical Android network, never the active TUN.
type Platform interface {
	Protect(fd int32) error
	Resolve(host string) (string, error)
	FindProcess(network, source string, sourcePort int32, destination string, destinationPort int32) (string, error)
}

var lifecycle sync.Mutex
var platform Platform
var instance *core.Instance
var vpn bool
var generation int64
var sequence int64
var batches = make(map[int64]*Batch)

func Configure(value Platform) {
	lifecycle.Lock()
	defer lifecycle.Unlock()
	platform = value
	// One immutable adapter, not an accumulating list of per-session controllers.
	// Unlike Xray's optional controllers, protection failures abort the dial.
	internet.UseAlternativeSystemDialer(internet.WithAdapter(physicalDialer{}))
	registerProcessFinder(value)
}

type physicalDialer struct{}

func (physicalDialer) Dial(network, address string) (net.Conn, error) {
	host, port, err := net.SplitHostPort(address)
	if err != nil {
		return nil, err
	}
	if net.ParseIP(host) == nil {
		resolved, err := platform.Resolve(host)
		if err != nil {
			return nil, err
		}
		host = strings.Split(resolved, "\n")[0]
		if net.ParseIP(host) == nil {
			return nil, errors.New("invalid physical DNS answer")
		}
	}
	dialer := net.Dialer{Timeout: 8 * time.Second, Control: func(_, _ string, raw syscall.RawConn) error {
		var protectErr error
		err := raw.Control(func(fd uintptr) { protectErr = platform.Protect(int32(fd)) })
		if err != nil {
			return err
		}
		return protectErr
	}}
	return dialer.Dial(network, net.JoinHostPort(host, port))
}

func ValidateXray(config string) error {
	_, err := serial.LoadJSONConfig(strings.NewReader(config))
	return err // Build only: constructing a second instance mutates Xray globals.
}

func start(config string) error {
	parsed, err := serial.LoadJSONConfig(strings.NewReader(config))
	if err != nil {
		return err
	}
	value, err := core.New(parsed)
	if err != nil {
		return err
	}
	if err = value.Start(); err != nil {
		_ = value.Close()
		return err
	}
	instance = value
	generation++
	return nil
}

func closeInstance() {
	for _, batch := range batches {
		batch.cancel()
	}
	if instance != nil {
		_ = instance.Close()
		instance = nil
	}
	xgrpc.CloseClientConnections("")
	generation++
}

func StartXray(config string, tunFD int32) error {
	lifecycle.Lock()
	defer lifecycle.Unlock()
	if vpn {
		return errors.New("Xray VPN is already running")
	}
	if platform == nil || tunFD < 3 {
		return errors.New("missing Android VPN platform or TUN")
	}
	// Ping-only instances may be replaced, but an active VPN is never replaced by a check.
	closeInstance()
	if err := os.Setenv("XRAY_TUN_FD", strconv.Itoa(int(tunFD))); err != nil {
		return err
	}
	err := start(config)
	_ = os.Unsetenv("XRAY_TUN_FD")
	vpn = err == nil
	return err
}

func StopXray() {
	lifecycle.Lock()
	defer lifecycle.Unlock()
	if vpn {
		closeInstance()
		vpn = false
	}
}

// Batch owns only its uniquely tagged test outbounds, never the VPN instance.
type Batch struct {
	id     int64
	epoch  int64
	tags   []string
	errors []string
	ctx    context.Context
	cancel context.CancelFunc
	closed bool
}

type outboundFailure struct{ errors chan error }

func (f *outboundFailure) SubmitError(err error) {
	select {
	case f.errors <- err:
	default:
	}
}

func OpenXrayBatch(outboundsJSON string) (*Batch, error) {
	lifecycle.Lock()
	defer lifecycle.Unlock()
	var configs []json.RawMessage
	if err := json.Unmarshal([]byte(outboundsJSON), &configs); err != nil {
		return nil, err
	}
	if len(configs) == 0 {
		return nil, errors.New("empty Xray check batch")
	}
	if instance == nil {
		if err := start(`{"log":{"loglevel":"none"},"outbounds":[{"protocol":"freedom","tag":"unused"}]}`); err != nil {
			return nil, err
		}
	}
	sequence++
	ctx, cancel := context.WithCancel(context.Background())
	b := &Batch{id: sequence, epoch: generation, ctx: ctx, cancel: cancel,
		tags: make([]string, len(configs)), errors: make([]string, len(configs))}
	batches[b.id] = b
	for index, encoded := range configs {
		var config conf.OutboundDetourConfig
		if err := json.Unmarshal(encoded, &config); err != nil {
			b.errors[index] = err.Error()
			continue
		}
		config.Tag = fmt.Sprintf("aora-check-%d-%d", b.id, index)
		built, err := config.Build()
		if err != nil {
			b.errors[index] = err.Error()
			continue
		}
		if err := core.AddOutboundHandler(instance, built); err != nil {
			b.errors[index] = err.Error()
			continue
		}
		b.tags[index] = config.Tag
	}
	return b, nil
}

func (b *Batch) NodeError(index int32) string {
	if index < 0 || int(index) >= len(b.errors) {
		return "Invalid check index"
	}
	return b.errors[index]
}

func (b *Batch) Check(index int32, method, target string) (int64, error) {
	if method != "GET" && method != "HEAD" {
		return 0, errors.New("unsupported HTTP method")
	}
	lifecycle.Lock()
	if b.closed || b.epoch != generation || index < 0 || int(index) >= len(b.tags) {
		lifecycle.Unlock()
		return 0, errors.New("Cancelled")
	}
	value, tag := instance, b.tags[index]
	lifecycle.Unlock()
	if tag == "" {
		return 0, errors.New(b.NodeError(index))
	}
	ctx, cancel := context.WithTimeout(b.ctx, 8*time.Second)
	defer cancel()
	failure := &outboundFailure{errors: make(chan error, 1)}
	ctx = session.TrackedConnectionError(ctx, failure)
	// A fresh transport excludes HTTP reuse between checks. Do not request
	// Connection: close: premature gRPC EOF can otherwise discard a valid reply.
	transport := &http.Transport{DialContext: func(ctx context.Context, _, address string) (net.Conn, error) {
		destination, err := xnet.ParseDestination("tcp:" + address)
		if err != nil {
			return nil, err
		}
		return core.Dial(session.SetForcedOutboundTagToContext(ctx, tag), value, destination)
	}}
	defer transport.CloseIdleConnections()
	client := http.Client{Transport: transport, Timeout: 8 * time.Second,
		CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}
	request, err := http.NewRequestWithContext(ctx, method, target, nil)
	if err != nil {
		return 0, err
	}
	watch := time.Now()
	response, err := client.Do(request)
	if err != nil {
		select {
		case cause := <-failure.errors:
			return 0, cause
		default:
		}
		return 0, err
	}
	defer response.Body.Close()
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		return 0, fmt.Errorf("test resource returned HTTP %d", response.StatusCode)
	}
	return time.Since(watch).Microseconds(), nil
}

func (b *Batch) closeLocked() {
	if b.closed {
		return
	}
	b.closed = true
	b.cancel()
	delete(batches, b.id)
	if instance != nil && b.epoch == generation {
		manager := instance.GetFeature(outbound.ManagerType()).(outbound.Manager)
		for _, tag := range b.tags {
			if tag != "" {
				_ = manager.RemoveHandler(context.Background(), tag)
				xgrpc.CloseClientConnections(tag)
			}
		}
	}
	if !vpn && len(batches) == 0 {
		closeInstance()
	}
}

func (b *Batch) Close() { lifecycle.Lock(); defer lifecycle.Unlock(); b.closeLocked() }
