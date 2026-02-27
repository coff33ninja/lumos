package main

import (
	"net"
	"strings"
)

type NetworkInterface struct {
	Name string   `json:"name"`
	MAC  string   `json:"mac"`
	IPs  []string `json:"ips"`
}

func getNetworkInterfaces() []NetworkInterface {
	var result []NetworkInterface

	ifaces, err := net.Interfaces()
	if err != nil {
		return result
	}

	for _, iface := range ifaces {
		// Skip loopback and down interfaces
		if iface.Flags&net.FlagLoopback != 0 || iface.Flags&net.FlagUp == 0 {
			continue
		}

		// Get MAC address
		mac := iface.HardwareAddr.String()
		if mac == "" {
			continue
		}

		// Get IP addresses
		addrs, err := iface.Addrs()
		if err != nil {
			continue
		}

		var ips []string
		for _, addr := range addrs {
			if ipnet, ok := addr.(*net.IPNet); ok && !ipnet.IP.IsLoopback() {
				if ipnet.IP.To4() != nil {
					ips = append(ips, ipnet.IP.String())
				}
			}
		}

		if len(ips) > 0 {
			result = append(result, NetworkInterface{
				Name: iface.Name,
				MAC:  strings.ToUpper(mac),
				IPs:  ips,
			})
		}
	}

	return result
}

func getPrimaryMAC() string {
	ifaces := getNetworkInterfaces()
	if len(ifaces) > 0 {
		return ifaces[0].MAC
	}
	return ""
}
