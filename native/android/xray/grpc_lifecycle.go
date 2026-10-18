// SPDX-License-Identifier: MPL-2.0
// Android integration extension to the pinned Xray gRPC transport.
package grpc

import (
	"context"
	"github.com/xtls/xray-core/common/session"
	"google.golang.org/grpc"
)

// Protected by globalDialerAccess, including calls from getGrpcClient.
var aoraClients = make(map[string]map[*grpc.ClientConn]struct{})

func aoraTrackClient(ctx context.Context, client *grpc.ClientConn) {
	if client == nil {
		return
	}
	entries := session.OutboundsFromContext(ctx)
	if len(entries) == 0 {
		return
	}
	tag := entries[len(entries)-1].Tag
	if aoraClients[tag] == nil {
		aoraClients[tag] = make(map[*grpc.ClientConn]struct{})
	}
	aoraClients[tag][client] = struct{}{}
}

// CloseClientConnections releases a test handler's transport, or all transports
// after the sole managed Xray instance stops. Never call with an empty tag just
// to end a scan while the VPN is running.
func CloseClientConnections(tag string) {
	globalDialerAccess.Lock()
	defer globalDialerAccess.Unlock()
	owned := aoraClients[tag]
	for key, client := range globalDialerMap {
		if _, exists := owned[client]; tag == "" || exists {
			if client != nil {
				_ = client.Close()
			}
			delete(globalDialerMap, key)
		}
	}
	if tag == "" {
		aoraClients = make(map[string]map[*grpc.ClientConn]struct{})
	} else {
		delete(aoraClients, tag)
	}
}
