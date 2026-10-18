// SPDX-License-Identifier: GPL-3.0-or-later
//go:build android

package mobile

import xnet "github.com/xtls/xray-core/common/net"

func registerProcessFinder(value Platform) {
	xnet.RegisterAndroidProcessFinder(func(network, source string, sourcePort uint16, destination string, destinationPort uint16) (int, string, string, error) {
		name, err := value.FindProcess(network, source, int32(sourcePort), destination, int32(destinationPort))
		return 0, name, "", err
	})
}
